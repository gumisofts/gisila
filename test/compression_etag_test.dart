import 'dart:convert';
import 'dart:io' show gzip;

import 'package:gisila/gisila.dart';
import 'package:gisila/testing.dart';
import 'package:test/test.dart';

final _big = {'items': List.generate(200, (i) => 'item number $i')};

GisilaTestClient _client({
  CompressionConfig? compression = const CompressionConfig(),
  EtagConfig? etags = const EtagConfig(),
}) {
  final app = GisilaApp(
      config: AppConfig(
          logRequests: false, compression: compression, etags: etags));
  app.registerController(attacher: (a, router, {prefix = ''}) {
    router.get('/big', (Request r) => jsonResponse(body: _big));
    router.get('/small', (Request r) => jsonResponse(body: {'ok': true}));
    router.get(
        '/png',
        (Request r) => Response.ok(List.filled(4096, 7),
            headers: {'content-type': 'image/png'}));
    router.get(
        '/stream',
        (Request r) => Response.ok(
            Stream.fromIterable([utf8.encode('a' * 10), utf8.encode('b')]),
            headers: {'content-type': 'text/plain'}));
    router.get(
        '/events',
        (Request r) => Response.ok(Stream.value(utf8.encode('data: x\n\n')),
            headers: {'content-type': 'text/event-stream'}));
    router.get(
        '/tagged',
        (Request r) => Response.ok(jsonEncode(_big), headers: {
              'content-type': 'application/json',
              'etag': '"v7"',
              'cache-control': 'max-age=60',
            }));
    router.get(
        '/secret',
        (Request r) => Response.ok(jsonEncode(_big), headers: {
              'content-type': 'application/json',
              'cache-control': 'no-store',
            }));
    router.post('/big', (Request r) => jsonResponse(body: _big));
  });
  return GisilaTestClient(app);
}

Object? _gunzip(TestResponse r) =>
    jsonDecode(utf8.decode(gzip.decode(r.bodyBytes)));

void main() {
  group('compression', () {
    final gz = {'accept-encoding': 'gzip, deflate, br'};

    test('gzips large JSON for clients that accept it', () async {
      final res = await _client(etags: null).get('/big', headers: gz);
      expect(res.headers['content-encoding'], 'gzip');
      expect(res.headers['vary'], 'Accept-Encoding');
      expect(res.bodyBytes.length, lessThan(jsonEncode(_big).length));
      expect(_gunzip(res), _big);
    });

    test('leaves small, binary and non-accepting responses alone', () async {
      final c = _client(etags: null);
      for (final (path, headers) in [
        ('/small', gz),
        ('/png', gz),
        ('/big', <String, String>{}),
        ('/big', {'accept-encoding': 'gzip;q=0, identity'}),
      ]) {
        final res = await c.get(path, headers: headers);
        expect(res.headers['content-encoding'], isNull,
            reason: '$path $headers');
      }
      // Compressible but sent plain: caches still need to know it varies.
      expect((await c.get('/big')).headers['vary'], 'Accept-Encoding');
    });

    test('streams of unknown length are compressed, SSE is not', () async {
      final c = _client(etags: null);
      final s = await c.get('/stream', headers: gz);
      expect(s.headers['content-encoding'], 'gzip');
      expect(s.headers['content-length'], isNull);
      expect(utf8.decode(gzip.decode(s.bodyBytes)), '${'a' * 10}b');
      final e = await c.get('/events', headers: gz);
      expect(e.headers['content-encoding'], isNull);
      expect(e.body, 'data: x\n\n');
    });

    test('shouldCompress can veto', () async {
      final c = _client(
          etags: null,
          compression: CompressionConfig(
              shouldCompress: (req, res) => req.url.path != 'big'));
      expect((await c.get('/big', headers: gz)).headers['content-encoding'],
          isNull);
    });

    test('acceptsGzip parses q-values', () {
      expect(acceptsGzip('gzip'), isTrue);
      expect(acceptsGzip('GZIP;q=0.5'), isTrue);
      expect(acceptsGzip('*'), isTrue);
      expect(acceptsGzip('gzip;q=0'), isFalse);
      expect(acceptsGzip('*;q=0.1, gzip;q=0'), isFalse);
      expect(acceptsGzip('br'), isFalse);
      expect(acceptsGzip(null), isFalse);
    });
  });

  group('etags', () {
    test('GET 200 gets an ETag; If-None-Match answers 304', () async {
      final c = _client(compression: null);
      final first = await c.get('/big');
      final tag = first.headers['etag']!;
      expect(tag, matches(RegExp(r'^"[0-9a-f]{32}"$')));
      expect(first.jsonMap, _big);

      final again = await c.get('/big', headers: {'if-none-match': tag});
      expect(again.statusCode, 304);
      expect(again.body, isEmpty);
      expect(again.headers['etag'], tag);

      final other = await c.get('/big', headers: {'if-none-match': '"nope"'});
      expect(other.statusCode, 200);
      final listed = await c.get('/big',
          headers: {'if-none-match': '"a", W/$tag'});
      expect(listed.statusCode, 304);
    });

    test("a handler's ETag is kept and 304 keeps cache headers", () async {
      final c = _client(compression: null);
      expect((await c.get('/tagged')).headers['etag'], '"v7"');
      final res = await c.get('/tagged', headers: {'if-none-match': '"v7"'});
      expect(res.statusCode, 304);
      expect(res.headers['cache-control'], 'max-age=60');
      expect(res.headers['content-type'], isNull);
    });

    test('no-store, non-GET and streams get none', () async {
      final c = _client(compression: null);
      expect((await c.get('/secret')).headers['etag'], isNull);
      expect((await c.post('/big')).headers['etag'], isNull);
      expect((await c.get('/stream')).headers['etag'], isNull);
    });

    test('with gzip the tag turns weak and still matches', () async {
      final c = _client();
      final gz = {'accept-encoding': 'gzip'};
      final plain = (await c.get('/big')).headers['etag']!;
      final zipped = await c.get('/big', headers: gz);
      expect(zipped.headers['etag'], 'W/$plain');
      final res = await c.get('/big',
          headers: {...gz, 'if-none-match': zipped.headers['etag']!});
      expect(res.statusCode, 304);
      expect(res.headers['content-encoding'], isNull);
    });

    test('security headers survive a 304', () async {
      final c = _client(compression: null);
      final tag = (await c.get('/big')).headers['etag']!;
      final res = await c.get('/big', headers: {'if-none-match': tag});
      expect(res.headers['x-content-type-options'], 'nosniff');
    });
  });
}
