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
        Request('OPTIONS', Uri.parse('http://example.test/x'),
            headers: {'origin': 'https://app.example'}),
      );
      expect(res.statusCode, 204);
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
  });
}
