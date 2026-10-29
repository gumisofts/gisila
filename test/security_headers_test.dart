import 'package:gisila/gisila.dart';
import 'package:gisila/testing.dart';
import 'package:test/test.dart';

import 'fixtures/guarded_controller.dart';

GisilaTestClient _client(AppConfig config) {
  final app = GisilaApp(config: config);
  app.registerController(attacher: (a, router, {prefix = ''}) {
    GuardedController().attachToApp(a, router, prefix: prefix);
    router.get(
        '/page',
        (Request r) => Response.ok('<html></html>',
            headers: {'content-type': 'text/html; charset=utf-8'}));
    router.get(
        '/framed',
        (Request r) => Response.ok('{}', headers: {
              'content-type': 'application/json',
              'x-frame-options': 'SAMEORIGIN',
              'set-cookie': 'a=1',
            }));
  });
  return GisilaTestClient(app);
}

void main() {
  test('defaults on JSON responses', () async {
    final res = await _client(AppConfig(logRequests: false)).get('/x/public');
    expect(res.headers['strict-transport-security'], 'max-age=15552000');
    expect(res.headers['x-content-type-options'], 'nosniff');
    expect(res.headers['x-frame-options'], 'DENY');
    expect(res.headers['referrer-policy'], 'no-referrer');
    expect(res.headers['content-security-policy'],
        "default-src 'none'; frame-ancestors 'none'");
  });

  test('error responses carry them too', () async {
    final c = _client(AppConfig(logRequests: false));
    for (final res in [await c.get('/x/me'), await c.get('/missing')]) {
      expect(res.statusCode, anyOf(401, 404));
      expect(res.headers['x-content-type-options'], 'nosniff');
    }
  });

  test('HTML gets no CSP unless configured', () async {
    final plain = await _client(AppConfig(logRequests: false)).get('/page');
    expect(plain.headers['content-security-policy'], isNull);
    expect(plain.headers['x-frame-options'], 'DENY');

    final strict = await _client(AppConfig(
            logRequests: false,
            securityHeaders: const SecurityHeadersConfig(
                htmlContentSecurityPolicy: "default-src 'self'")))
        .get('/page');
    expect(strict.headers['content-security-policy'], "default-src 'self'");
  });

  test('headers the handler set are kept', () async {
    final res = await _client(AppConfig(logRequests: false)).get('/framed');
    expect(res.headers['x-frame-options'], 'SAMEORIGIN');
    expect(res.headers['set-cookie'], 'a=1');
  });

  test('fields can be turned off, HSTS tuned, extras added', () async {
    final res = await _client(AppConfig(
            logRequests: false,
            securityHeaders: const SecurityHeadersConfig(
              hsts: HstsConfig(
                  maxAge: Duration(days: 365),
                  includeSubDomains: true,
                  preload: true),
              frameOptions: null,
              contentSecurityPolicy: null,
              extra: {'Permissions-Policy': 'camera=()'},
            )))
        .get('/x/public');
    expect(res.headers['strict-transport-security'],
        'max-age=31536000; includeSubDomains; preload');
    expect(res.headers['x-frame-options'], isNull);
    expect(res.headers['content-security-policy'], isNull);
    expect(res.headers['permissions-policy'], 'camera=()');
  });

  test('securityHeaders: null sends none', () async {
    final res = await _client(AppConfig(logRequests: false, securityHeaders: null))
        .get('/x/public');
    expect(res.headers['x-content-type-options'], isNull);
    expect(res.headers['strict-transport-security'], isNull);
  });
}
