import 'dart:convert';

import 'package:gisila/gisila.dart';
import 'package:test/test.dart';

void main() {
  group('guardRequest', () {
    late GisilaApp app;
    late Handler handler;

    setUp(() {
      app = GisilaApp(
        config: AppConfig(
          logRequests: false,
          authenticator: const StaticTokenAuthenticator({
            'good': Principal(
              id: 'u1',
              roles: {'admin'},
              permissions: {'read', 'write'},
            ),
            'reader': Principal(id: 'u2', permissions: {'read'}),
          }),
        ),
      );
      final router = Router();

      // Open route.
      router.get('/open', (Request req) async {
        return Response.ok('open');
      });

      // RequireAuth route - permission required.
      router.post('/write', (Request req) async {
        final r = await guardRequest(
          req,
          requireAuth: true,
          permissions: const {'write'},
        );
        if (r is Response) return r;
        return Response.ok('ok');
      });

      // Roles route.
      router.get('/admin', (Request req) async {
        final r = await guardRequest(
          req,
          requireAuth: true,
          roles: const {'admin'},
        );
        if (r is Response) return r;
        return Response.ok('admin');
      });

      app.registerController(
        attacher: (GisilaApp _, Router r, {String prefix = ''}) {
          // Tests use a single shared router - nothing extra to attach.
        },
      );
      // Build the full pipeline (so the app context is attached).
      handler = const Pipeline()
          .addMiddleware((inner) => (Request r) {
                final req = r.change(context: {...r.context, kAppKey: app});
                return inner(req);
              })
          .addHandler(router.call);
    });

    test('open route works without credentials', () async {
      final res = await handler(Request('GET', Uri.parse('http://x/open')));
      expect(res.statusCode, 200);
    });

    test('returns 401 when no credentials', () async {
      final res = await handler(Request('POST', Uri.parse('http://x/write')));
      expect(res.statusCode, 401);
      final body = jsonDecode(await res.readAsString()) as Map;
      expect((body['error'] as Map)['code'], 'unauthorized');
    });

    test('returns 403 when authenticated but missing permission', () async {
      final res = await handler(Request(
        'POST',
        Uri.parse('http://x/write'),
        headers: {'authorization': 'Bearer reader'},
      ));
      expect(res.statusCode, 403);
    });

    test('passes through when all checks succeed', () async {
      final res = await handler(Request(
        'POST',
        Uri.parse('http://x/write'),
        headers: {'authorization': 'Bearer good'},
      ));
      expect(res.statusCode, 200);
      expect(await res.readAsString(), 'ok');
    });

    test('enforces role-based guards', () async {
      final reader = await handler(Request(
        'GET',
        Uri.parse('http://x/admin'),
        headers: {'authorization': 'Bearer reader'},
      ));
      expect(reader.statusCode, 403);

      final admin = await handler(Request(
        'GET',
        Uri.parse('http://x/admin'),
        headers: {'authorization': 'Bearer good'},
      ));
      expect(admin.statusCode, 200);
    });
  });
}
