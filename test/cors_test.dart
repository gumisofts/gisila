import 'package:gisila/gisila.dart';
import 'package:test/test.dart';

void main() {
  group('corsMiddleware', () {
    Future<Response> run(
      CorsConfig config,
      Request request, [
      Handler? inner,
    ]) async {
      final pipeline = const Pipeline().addMiddleware(corsMiddleware(config));
      final handler =
          pipeline.addHandler(inner ?? (_) async => Response.ok('hi'));
      return handler(request);
    }

    test('answers OPTIONS pre-flight with 204 and ACA headers', () async {
      final res = await run(
        const CorsConfig(allowedOrigins: {'https://app.example'}),
        Request('OPTIONS', Uri.parse('http://example.test/x'), headers: {
          'origin': 'https://app.example',
          'access-control-request-method': 'POST',
        }),
      );
      expect(res.statusCode, 204);
      expect(res.headers['vary'], contains('Origin'));
      expect(res.headers['access-control-allow-origin'], 'https://app.example');
      expect(res.headers['access-control-allow-methods'], contains('POST'));
    });

    test('echoes origin on real requests when in allow-list', () async {
      final res = await run(
        const CorsConfig(allowedOrigins: {'https://allowed'}),
        Request('GET', Uri.parse('http://example.test/x'),
            headers: {'origin': 'https://allowed'}),
      );
      expect(res.statusCode, 200);
      expect(res.headers['access-control-allow-origin'], 'https://allowed');
    });

    test('omits ACAO for origins not in allow-list', () async {
      final res = await run(
        const CorsConfig(allowedOrigins: {'https://allowed'}),
        Request('GET', Uri.parse('http://example.test/x'),
            headers: {'origin': 'https://evil'}),
      );
      expect(res.statusCode, 200);
      expect(res.headers['access-control-allow-origin'], isNull);
    });

    group('FW-08', () {
      Request preflight(String origin) =>
          Request('OPTIONS', Uri.parse('http://example.test/x'), headers: {
            'origin': origin,
            'access-control-request-method': 'DELETE',
          });

      test("refuses '*' with credentials instead of echoing any origin", () {
        expect(() => corsMiddleware(const CorsConfig(allowCredentials: true)),
            throwsArgumentError);
      });

      test('credentials with listed origins echo only those', () async {
        const config = CorsConfig(
            allowedOrigins: {'https://app.example'}, allowCredentials: true);
        final ok = await run(
            config,
            Request('GET', Uri.parse('http://example.test/x'),
                headers: {'origin': 'https://app.example'}));
        expect(
            ok.headers['access-control-allow-origin'], 'https://app.example');
        expect(ok.headers['access-control-allow-credentials'], 'true');
        final evil = await run(
            config,
            Request('GET', Uri.parse('http://example.test/x'),
                headers: {'origin': 'https://evil'}));
        expect(evil.headers['access-control-allow-origin'], isNull);
        expect(evil.headers['access-control-allow-credentials'], isNull);
        expect(evil.headers['vary'], 'Origin');
      });

      test('a pre-flight from a disallowed origin gets 403', () async {
        final res = await run(
            const CorsConfig(allowedOrigins: {'https://app.example'}),
            preflight('https://evil'));
        expect(res.statusCode, 403);
        expect(res.headers['access-control-allow-origin'], isNull);
      });

      test('a plain OPTIONS request reaches the handler', () async {
        final res = await run(
          const CorsConfig(allowedOrigins: {'https://app.example'}),
          Request('OPTIONS', Uri.parse('http://example.test/x')),
          (_) async => Response(405),
        );
        expect(res.statusCode, 405);
      });

      test('the open default still answers any pre-flight with *', () async {
        final res = await run(const CorsConfig(), preflight('https://any'));
        expect(res.statusCode, 204);
        expect(res.headers['access-control-allow-origin'], '*');
        expect(res.headers['vary'], isNull);
      });
    });
  });
}
