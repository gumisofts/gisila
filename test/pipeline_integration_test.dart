/// Requests through `GisilaApp.buildHandler()` to a controller whose routes
/// were produced by the code generator (`fixtures/guarded_controller.dart`),
/// so guards, binding, timeouts, rate limits and error mapping are tested
/// the way an app runs them.
library;

import 'dart:convert';

import 'package:gisila/gisila.dart';
import 'package:test/test.dart';

import 'fixtures/guarded_controller.dart';

void main() {
  late Handler handler;

  setUp(() {
    final app = GisilaApp(
      config: AppConfig(
        logRequests: false,
        cors: const CorsConfig(allowedOrigins: {'https://ui.test'}),
        authenticator: const StaticTokenAuthenticator({
          'admin':
              Principal(id: 'u1', roles: {'admin'}, permissions: {'write'}),
          'reader': Principal(id: 'u2'),
        }),
      ),
    );
    app.registerController(
        attacher: (a, router, {prefix = ''}) =>
            GuardedController().attachToApp(a, router, prefix: prefix));
    handler = app.buildHandler();
  });

  Future<Response> send(String method, String path,
          {String? token, Object? json, Map<String, String>? headers}) async =>
      handler(Request(method, Uri.parse('http://api.test$path'),
          headers: {
            if (token != null) 'authorization': 'Bearer $token',
            if (json != null) 'content-type': 'application/json',
            ...?headers,
          },
          body: json == null ? null : jsonEncode(json)));

  Future<Map<String, Object?>> body(Response r) async =>
      jsonDecode(await r.readAsString()) as Map<String, Object?>;

  group('guards from annotations', () {
    test("@Get('/') answers with and without the trailing slash", () async {
      expect((await send('GET', '/x')).statusCode, 200);
      expect((await send('GET', '/x/')).statusCode, 200);
    });

    test('@Public overrides the class-level @RequireAuth', () async {
      expect((await send('GET', '/x/public')).statusCode, 200);
    });

    test('no or unknown credentials get a 401 envelope', () async {
      for (final token in [null, 'nope']) {
        final r = await send('GET', '/x/me', token: token);
        expect(r.statusCode, 401, reason: token);
        expect((await body(r))['error'], isA<Map<String, Object?>>());
      }
    });

    test('the principal reaches the handler', () async {
      final r = await send('GET', '/x/me', token: 'reader');
      expect(await body(r), {'id': 'u2'});
    });

    test('@Permissions and @Roles answer 403 without them', () async {
      expect(
          (await send('POST', '/x/notes',
                  token: 'reader', json: {'title': 'a'}))
              .statusCode,
          403);
      expect((await send('GET', '/x/admin', token: 'reader')).statusCode, 403);
      expect((await send('GET', '/x/admin', token: 'admin')).statusCode, 200);
    });
  });

  group('binding', () {
    test('a form is validated and bound', () async {
      final ok = await send('POST', '/x/notes',
          token: 'admin', json: {'title': 'hi', 'stars': 4});
      expect(ok.statusCode, 201); // POST's default
      expect(await body(ok), {'title': 'hi', 'stars': 4});

      final bad =
          await send('POST', '/x/notes', token: 'admin', json: {'stars': 9});
      expect(bad.statusCode, 400);
      final details = ((await body(bad))['error'] as Map)['details'] as Map;
      expect(details.keys, containsAll(['title', 'stars']));
    });

    test('path and query parameters are converted, or 400', () async {
      expect(await body(await send('GET', '/x/items/7?page=2')),
          {'id': 7, 'page': 2});
      expect(await body(await send('GET', '/x/items/7?page=')),
          {'id': 7, 'page': null});
      expect((await send('GET', '/x/items/seven')).statusCode, 400);
      expect((await send('GET', '/x/items/7?page=x')).statusCode, 400);
    });
  });

  group('route config', () {
    test('a route timeout answers 504', () async {
      expect((await send('GET', '/x/slow')).statusCode, 504);
    });

    test('a route rate limit answers 429 past its budget', () async {
      final codes = [
        for (var i = 0; i < 3; i++) (await send('GET', '/x/limited')).statusCode
      ];
      expect(codes, [200, 200, 429]);
    });
  });

  group('pipeline', () {
    test('an unexpected error is a generic 500, not its message', () async {
      final r = await send('GET', '/x/boom');
      expect(r.statusCode, 500);
      expect(await r.readAsString(), isNot(contains('secret detail')));
    });

    test('a CORS pre-flight is answered before auth', () async {
      final r = await send('OPTIONS', '/x/me', headers: {
        'origin': 'https://ui.test',
        'access-control-request-method': 'GET',
      });
      expect(r.statusCode, 204);
      expect(r.headers['access-control-allow-origin'], 'https://ui.test');
    });

    test('no Server or X-Powered-By header unless asked for (FW-14)', () async {
      final r = await send('GET', '/x/public');
      expect(r.headers['server'], isNull);
      expect(r.headers['x-powered-by'], isNull);
    });

    test('an unknown route is a JSON 404 (FW-14)', () async {
      final r = await send('GET', '/nope/"quoted"');
      expect(r.statusCode, 404);
      expect(r.headers['content-type'], startsWith('application/json'));
      expect(((await body(r))['error'] as Map)['code'], 'not_found');
    });

    test('responses carry a request id', () async {
      final r = await send('GET', '/x/public');
      expect(r.headers['x-request-id'], isNotEmpty);
    });
  });

  group('shared rate-limit store (PNL-20)', () {
    Handler appWith(RateLimitStore? store) {
      final app = GisilaApp(
        config: AppConfig(logRequests: false, rateLimitStore: store),
      );
      app.registerController(
          attacher: (a, router, {prefix = ''}) =>
              GuardedController().attachToApp(a, router, prefix: prefix));
      return app.buildHandler();
    }

    Future<int> hit(Handler h) async =>
        (await h(Request('GET', Uri.parse('http://api.test/x/limited'))))
            .statusCode;

    test('two apps (isolates) sharing a store share the budget', () async {
      final store = InMemoryRateLimitStore();
      final a = appWith(store);
      final b = appWith(store);
      expect([await hit(a), await hit(b), await hit(a)], [200, 200, 429]);
    });

    test('without one, each app allows the full rate', () async {
      final a = appWith(null);
      final b = appWith(null);
      expect([await hit(a), await hit(a), await hit(b), await hit(b)],
          [200, 200, 200, 200]);
    });

    test('route buckets are named by method and path', () async {
      final keys = <String>[];
      final store = _RecordingStore(keys);
      await hit(appWith(store));
      expect(keys.single, startsWith('route:GET /x/limited|'));
    });
  });
}

class _RecordingStore implements RateLimitStore {
  _RecordingStore(this.keys);
  final List<String> keys;

  @override
  Duration? take(String key,
      {required double capacity, required double refillPerSecond}) {
    keys.add(key);
    return null;
  }
}
