import 'package:gisila/gisila.dart';
import 'package:test/test.dart';

class _Throwing extends Authenticator {
  const _Throwing(this.error);
  final Object error;

  @override
  Future<Principal?> authenticate(Request request) async => throw error;
}

class _Capture extends Logger {
  final events = <LogEvent>[];

  @override
  LogLevel get level => LogLevel.trace;

  @override
  void log(LogEvent event) => events.add(event);
}

void main() {
  group('FW-10 authenticator errors', () {
    Future<(Response, _Capture)> call(Object error) async {
      final logger = _Capture();
      final app = GisilaApp(
        config: AppConfig(
          logRequests: false,
          logger: logger,
          authenticator: _Throwing(error),
        ),
      );
      final router = Router()
        ..get(
          '/me',
          gisilaRoute(
            app: app,
            config: const RouteConfig(requireAuth: true),
            handler: (ctx) => Response.ok('in'),
          ),
        );
      final res =
          await router(Request('GET', Uri.parse('http://localhost/me')));
      return (res, logger);
    }

    test('an internal error becomes a generic 401 and is logged', () async {
      final (res, logger) = await call(StateError(
          'connection to db.internal:5432 failed (password authentication)'));
      expect(res.statusCode, 401);
      final body = await res.readAsString();
      expect(body, contains('Authentication required'));
      expect(body, isNot(contains('db.internal')));
      expect(logger.events.single.error.toString(), contains('db.internal'));
    });

    test("an authenticator's own 401/403 goes out as is", () async {
      final (expired, _) = await call(Unauthorized('Token expired'));
      expect(expired.statusCode, 401);
      expect(await expired.readAsString(), contains('Token expired'));
      final (denied, logger) = await call(Forbidden('Account disabled'));
      expect(denied.statusCode, 403);
      expect(await denied.readAsString(), contains('Account disabled'));
      expect(logger.events, isEmpty);
    });
  });
}
