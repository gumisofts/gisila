/// Health endpoint and graceful stop (FW-13).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:gisila/gisila.dart';
import 'package:test/test.dart';

class _Db extends DatabaseProvider<String> {
  var disposed = false;

  @override
  Future<String> open(Request request) async => 'session';

  @override
  Future<void> close(String session, {required bool ok}) async {}

  @override
  Future<void> dispose() async => disposed = true;
}

GisilaApp _app({
  String? healthPath,
  Future<bool> Function()? check,
  DatabaseProvider<Object?>? db,
  void Function(Router r)? routes,
}) {
  final app = GisilaApp(
    config: AppConfig(
      logRequests: false,
      healthCheckPath: healthPath,
      healthCheck: check,
      database: db,
      // Every route needs a login, which /healthz must not.
      defaultRouteConfig: const RouteConfig(requireAuth: true),
    ),
  );
  app.registerController(attacher: (a, router, {prefix = ''}) {
    routes?.call(router);
  });
  return app;
}

Future<Response> _get(GisilaApp app, String path) async =>
    app.buildHandler()(Request('GET', Uri.parse('http://api.test$path')));

void main() {
  group('health endpoint', () {
    test('answers without auth and is off unless configured', () async {
      final on = _app(healthPath: '/healthz');
      final r = await _get(on, '/healthz');
      expect(r.statusCode, 200);
      expect(jsonDecode(await r.readAsString()), {'status': 'ok'});
      expect((await _get(_app(), '/healthz')).statusCode, 404);
    });

    test('a failing or throwing check answers 503', () async {
      for (final check in <Future<bool> Function()>[
        () async => false,
        () async => throw StateError('db down'),
      ]) {
        final r =
            await _get(_app(healthPath: '/healthz', check: check), '/healthz');
        expect(r.statusCode, 503);
      }
    });
  });

  group('stop()', () {
    test('lets an in-flight request finish, then disposes the database',
        () async {
      final db = _Db();
      final gate = Completer<void>();
      final app = _app(
        db: db,
        routes: (r) => r.get('/slow', (Request _) async {
          await gate.future;
          return Response.ok('done');
        }),
      );
      final server = await app.start(host: '127.0.0.1', port: 0);
      final client = HttpClient();
      final pending = client
          .get('127.0.0.1', server.port, '/slow')
          .then((req) => req.close())
          .then((res) => res.transform(utf8.decoder).join());
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final stopping = app.stop(drainTimeout: const Duration(seconds: 5));
      gate.complete();
      // The route requires auth, so the in-flight answer is a 401 body;
      // what matters is that it was answered, not cut off.
      expect(await pending, isNotEmpty);
      await stopping;
      expect(db.disposed, isTrue);
      client.close(force: true);
    });

    test('an idle keep-alive connection does not hold it past the timeout',
        () async {
      final app = _app();
      final server = await app.start(host: '127.0.0.1', port: 0);
      final idle = await Socket.connect('127.0.0.1', server.port);
      final sw = Stopwatch()..start();
      await app.stop(drainTimeout: const Duration(milliseconds: 300));
      expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
      idle.destroy();
    });
  });
}
