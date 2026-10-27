import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpConnectionInfo, InternetAddress;
import 'dart:typed_data';

import 'package:gisila/gisila.dart';
import 'package:test/test.dart';

class _Conn implements HttpConnectionInfo {
  _Conn(String ip) : remoteAddress = InternetAddress(ip);
  @override
  final InternetAddress remoteAddress;
  @override
  int get remotePort => 40000;
  @override
  int get localPort => 8080;
}

Request _req(
  String method,
  String path, {
  String? peer,
  Map<String, String>? headers,
  Object? body,
}) =>
    Request(
      method,
      Uri.parse('http://x$path'),
      headers: headers,
      body: body,
      context: {
        if (peer != null) 'shelf.io.connection_info': _Conn(peer),
      },
    );

class _FakeDb extends DatabaseProvider<String> {
  int opened = 0;
  final closed = <bool>[];
  bool failOpen = false;
  final closedSignal = StreamController<bool>.broadcast();

  @override
  Future<String> open(Request request) async {
    if (failOpen) throw StateError('pool exhausted');
    opened++;
    return 'session';
  }

  @override
  Future<void> close(String session, {required bool ok}) async {
    closed.add(ok);
    closedSignal.add(ok);
  }
}

Handler _app(
  AppConfig config,
  void Function(GisilaApp app, Router r) routes,
) {
  final app = GisilaApp(config: config);
  app.registerController(
    attacher: (GisilaApp a, Router r, {String prefix = ''}) => routes(a, r),
  );
  return app.buildHandler();
}

void main() {
  group('FW-01 rate limiter keys', () {
    Handler limited(RateLimitConfig cfg) => const Pipeline()
        .addMiddleware(rateLimitMiddleware(cfg))
        .addHandler((_) => Response.ok('ok'));

    test('separate clients get separate buckets', () async {
      final h = limited(const RateLimitConfig(requestsPerMinute: 1));
      expect((await h(_req('GET', '/', peer: '1.1.1.1'))).statusCode, 200);
      expect((await h(_req('GET', '/', peer: '1.1.1.1'))).statusCode, 429);
      expect((await h(_req('GET', '/', peer: '2.2.2.2'))).statusCode, 200);
    });

    test('X-Forwarded-For is ignored without trusted proxies', () async {
      final h = limited(const RateLimitConfig(requestsPerMinute: 1));
      await h(_req('GET', '/', peer: '1.1.1.1'));
      final spoofed = await h(_req('GET', '/',
          peer: '1.1.1.1', headers: {'x-forwarded-for': '9.9.9.9'}));
      expect(spoofed.statusCode, 429);
      expect(int.parse(spoofed.headers['retry-after']!), greaterThan(0));
    });

    test('X-Forwarded-For from a trusted proxy picks the real client',
        () async {
      final h = limited(const RateLimitConfig(
        requestsPerMinute: 1,
        trustedProxies: {'10.0.0.0/8'},
      ));
      Request viaProxy(String xff) =>
          _req('GET', '/', peer: '10.1.2.3', headers: {'x-forwarded-for': xff});
      // Left-most entries are client-controlled; the right-most
      // untrusted hop is the one the proxy saw.
      expect((await h(viaProxy('6.6.6.6, 1.1.1.1'))).statusCode, 200);
      expect((await h(viaProxy('7.7.7.7, 1.1.1.1'))).statusCode, 429);
      expect((await h(viaProxy('1.1.1.1, 2.2.2.2, 10.0.0.9'))).statusCode, 200);
    });

    test('clientAddress ignores the header from untrusted peers', () {
      final r = _req('GET', '/',
          peer: '5.5.5.5', headers: {'x-forwarded-for': '9.9.9.9'});
      expect(clientAddress(r, trustedProxies: {'10.0.0.0/8'}), '5.5.5.5');
      expect(clientAddress(r), '5.5.5.5');
    });

    test('rejects malformed trusted proxy entries up front', () {
      expect(
        () => rateLimitMiddleware(
            const RateLimitConfig(trustedProxies: {'10.0.0.0/33'})),
        throwsArgumentError,
      );
    });

    test('apps trust a local reverse proxy by default', () async {
      final h = _app(
        AppConfig(
          logRequests: false,
          rateLimit: const RateLimitConfig(requestsPerMinute: 1),
        ),
        (app, r) => r.get('/', (Request _) => Response.ok('ok')),
      );
      Request viaNginx(String client) => _req('GET', '/',
          peer: '127.0.0.1', headers: {'x-forwarded-for': client});
      expect((await h(viaNginx('1.1.1.1'))).statusCode, 200);
      expect((await h(viaNginx('2.2.2.2'))).statusCode, 200);
      expect((await h(viaNginx('1.1.1.1'))).statusCode, 429);
    });

    test('bucket map is bounded', () async {
      final h =
          limited(const RateLimitConfig(requestsPerMinute: 1, maxBuckets: 2));
      await h(_req('GET', '/', peer: '1.1.1.1'));
      await h(_req('GET', '/', peer: '2.2.2.2'));
      await h(_req('GET', '/', peer: '3.3.3.3'));
      // 1.1.1.1 was the least recently used and got evicted, so it
      // starts with a fresh bucket.
      expect((await h(_req('GET', '/', peer: '1.1.1.1'))).statusCode, 200);
    });
  });

  group('FW-02 multi-value headers', () {
    test('Set-Cookie survives CORS, request id and server headers', () async {
      final h = _app(
        AppConfig(
          logRequests: false,
          cors: const CorsConfig(allowedOrigins: {'https://app'}),
          serverHeader: 'test',
        ),
        (app, r) => r.get(
          '/c',
          (Request _) => Response.ok('ok', headers: {
            'set-cookie': ['a=1; Path=/', 'b=2; Path=/'],
          }),
        ),
      );
      final res =
          await h(_req('GET', '/c', headers: {'origin': 'https://app'}));
      expect(res.headersAll['set-cookie'], ['a=1; Path=/', 'b=2; Path=/']);
      expect(res.headers['access-control-allow-origin'], 'https://app');
      expect(res.headers['vary'], 'Origin');
      expect(res.headers['x-request-id'], isNotEmpty);
      expect(res.headers['server'], isNotEmpty);
    });

    test('unsafe incoming request ids are replaced', () async {
      final h = _app(AppConfig(logRequests: false),
          (app, r) => r.get('/', (Request _) => Response.ok('ok')));
      final good =
          await h(_req('GET', '/', headers: {'x-request-id': 'abc-1'}));
      expect(good.headers['x-request-id'], 'abc-1');
      final bad =
          await h(_req('GET', '/', headers: {'x-request-id': 'a b"<script>'}));
      expect(bad.headers['x-request-id'], isNot(contains(' ')));
    });
  });

  group('FW-03 body limits', () {
    Handler echo(AppConfig config) => _app(
          config,
          (app, r) => r.post('/e', (Request req) async {
            final body = await readJsonBody(req);
            return Response.ok(jsonEncode(body));
          }),
        );

    test('chunked body over the limit is refused with 413', () async {
      final h = echo(AppConfig(logRequests: false, maxRequestBodyBytes: 16));
      final res = await h(_req('POST', '/e',
          headers: {'content-type': 'application/json'},
          body: Stream<List<int>>.fromIterable([
            utf8.encode('{"a":"'),
            List.filled(64, 0x61),
            utf8.encode('"}')
          ])));
      expect(res.statusCode, 413);
      final err = (jsonDecode(await res.readAsString()) as Map)['error'] as Map;
      expect(err['code'], 'payload_too_large');
    });

    // dart:io hands shelf a Stream<Uint8List>; a List<int> transformer
    // used to fail its runtime type check on every request.
    test('a Uint8List body stream (as from dart:io) passes', () async {
      final h = echo(AppConfig(logRequests: false, maxRequestBodyBytes: 64));
      final res = await h(_req('POST', '/e',
          headers: {'content-type': 'application/json'},
          body: Stream<Uint8List>.fromIterable(
              [Uint8List.fromList(utf8.encode('{"a":1}'))])));
      expect(res.statusCode, 200);
      expect(await res.readAsString(), '{"a":1}');
    });

    test('a Uint8List body stream over the limit is refused', () async {
      final h = echo(AppConfig(logRequests: false, maxRequestBodyBytes: 16));
      final res = await h(_req('POST', '/e',
          headers: {'content-type': 'application/json'},
          body: Stream<Uint8List>.fromIterable([Uint8List(64)])));
      expect(res.statusCode, 413);
    });

    test('chunked body under the limit passes', () async {
      final h = echo(AppConfig(logRequests: false, maxRequestBodyBytes: 64));
      final res = await h(_req('POST', '/e',
          headers: {'content-type': 'application/json'},
          body: Stream<List<int>>.fromIterable([utf8.encode('{"a":1}')])));
      expect(res.statusCode, 200);
    });

    test('request body logging does not bypass the limit', () async {
      final h = echo(AppConfig(
        maxRequestBodyBytes: 16,
        logRequestBody: true,
        logger: ConsoleLogger(level: LogLevel.error),
      ));
      final res = await h(_req('POST', '/e',
          headers: {'content-type': 'application/json'},
          body: Stream<List<int>>.fromIterable([List.filled(64, 0x61)])));
      expect(res.statusCode, 413);
    });

    String multipart(int parts, {int fieldSize = 1}) {
      const b = 'bnd';
      final sb = StringBuffer();
      for (var i = 0; i < parts; i++) {
        sb
          ..write('--$b\r\n')
          ..write('Content-Disposition: form-data; name="f$i"\r\n\r\n')
          ..write('x' * fieldSize)
          ..write('\r\n');
      }
      sb.write('--$b--\r\n');
      return sb.toString();
    }

    Future<FormData> parse(String body,
            {int maxParts = 1000, int maxField = 1024}) =>
        parseFormData(
          headers: {'content-type': 'multipart/form-data; boundary=bnd'},
          body: () async => body,
          bytes: () => Stream.value(utf8.encode(body)),
          maxParts: maxParts,
          maxFieldBytes: maxField,
        );

    test('multipart part count is capped', () async {
      expect((await parse(multipart(3), maxParts: 3)).fields, hasLength(3));
      await expectLater(parse(multipart(4), maxParts: 3),
          throwsA(isA<BadRequestException>()));
    });

    test('multipart field size is capped', () async {
      await expectLater(parse(multipart(1, fieldSize: 2000), maxField: 1024),
          throwsA(isA<BadRequestException>()));
    });
  });

  group('FW-04 DB session placement', () {
    late _FakeDb db;
    late Handler h;

    setUp(() {
      db = _FakeDb();
      h = _app(
        AppConfig(
          logRequests: false,
          database: db,
          cors: const CorsConfig(allowedOrigins: {'https://app'}),
          rateLimit: const RateLimitConfig(requestsPerMinute: 1),
        ),
        (app, r) => r.get('/d', (Request _) => Response.ok('ok')),
      );
    });

    test('pre-flight does not take a session', () async {
      final res = await h(_req('OPTIONS', '/d', peer: '1.1.1.1', headers: {
        'origin': 'https://app',
        'access-control-request-method': 'GET',
      }));
      expect(res.statusCode, 204);
      expect(db.opened, 0);
    });

    test('rate-limited request does not take a session', () async {
      await h(_req('GET', '/d', peer: '1.1.1.1'));
      final res = await h(_req('GET', '/d', peer: '1.1.1.1'));
      expect(res.statusCode, 429);
      expect(db.opened, 1);
      expect(db.closed, [true]);
    });

    test('open failure is a JSON 500 with CORS headers', () async {
      db.failOpen = true;
      final res = await h(_req('GET', '/d',
          peer: '1.1.1.1', headers: {'origin': 'https://app'}));
      expect(res.statusCode, 500);
      expect(res.headers['content-type'], contains('application/json'));
      expect(res.headers['access-control-allow-origin'], 'https://app');
    });
  });

  group('FW-05 timeouts', () {
    test('session outlives a timed-out handler and is rolled back', () async {
      final db = _FakeDb();
      final release = Completer<void>();
      late RequestContext seen;
      final h = _app(
        AppConfig(
          logRequests: false,
          database: db,
          requestTimeout: const Duration(milliseconds: 20),
        ),
        (app, r) => r.get(
          '/slow',
          gisilaRoute(
            app: app,
            config: const RouteConfig(),
            handler: (ctx) async {
              seen = ctx;
              await release.future;
              // Still allowed to touch the session here.
              expect(ctx.db<String>(), 'session');
              return Response.ok('late');
            },
          ),
        ),
      );

      final res = await h(_req('GET', '/slow'));
      expect(res.statusCode, 504);
      expect(seen.cancellation.isCancelled, isTrue);
      expect(db.closed, isEmpty, reason: 'handler still running');

      final closed = db.closedSignal.stream.first;
      release.complete();
      expect(await closed, isFalse);
      expect(db.closed, [false]);
    });

    test('a TimeoutException thrown by the handler is not a 504', () async {
      final h = _app(
        AppConfig(
          logRequests: false,
          requestTimeout: const Duration(seconds: 5),
        ),
        (app, r) =>
            r.get('/t', (Request _) => throw TimeoutException('upstream slow')),
      );
      final res = await h(_req('GET', '/t'));
      expect(res.statusCode, 500);
    });

    test('route-level timeout cancels too', () async {
      final release = Completer<void>();
      late RequestContext seen;
      final h = _app(
        AppConfig(logRequests: false),
        (app, r) => r.get(
          '/slow',
          gisilaRoute(
            app: app,
            config: const RouteConfig(timeout: Duration(milliseconds: 20)),
            handler: (ctx) async {
              seen = ctx;
              await release.future;
              return Response.ok('late');
            },
          ),
        ),
      );
      final res = await h(_req('GET', '/slow'));
      expect(res.statusCode, 504);
      expect(seen.cancellation.isCancelled, isTrue);
      expect(seen.cancellation.throwIfCancelled,
          throwsA(isA<RequestCancelledException>()));
      release.complete();
    });
  });

  group('FW-06 guards without the app pipeline', () {
    final app = GisilaApp(
      config: AppConfig(
        logRequests: false,
        authenticator: const StaticTokenAuthenticator({
          'good': Principal(id: 'u1'),
        }),
      ),
    );

    test('gisilaRoute guards hold on a bare router', () async {
      final router = Router()
        ..get(
          '/me',
          gisilaRoute(
            app: app,
            config: const RouteConfig(requireAuth: true),
            handler: (ctx) => Response.ok(ctx.principal!.id),
          ),
        );
      expect((await router(_req('GET', '/me'))).statusCode, 401);
      final ok = await router(
          _req('GET', '/me', headers: {'authorization': 'Bearer good'}));
      expect(ok.statusCode, 200);
      expect(await ok.readAsString(), 'u1');
    });

    test('guardRequest fails closed without an app', () async {
      final r = await guardRequest(_req('GET', '/'), requireAuth: true);
      expect(r, isA<Response>());
      expect((r as Response).statusCode, 500);
      final open = await guardRequest(_req('GET', '/'), requireAuth: false);
      expect(open, isA<RequestContext>());
    });
  });
}
