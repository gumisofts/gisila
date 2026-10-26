/// Per-request database session middleware.
///
/// When `AppConfig.database` is set, [GisilaApp] installs this
/// middleware inside CORS, rate limiting, the body cap and the error
/// mapper, so pre-flights and rejected requests never take a pooled
/// connection and a failing `provider.open` renders a normal JSON
/// error. For every request it:
///
/// 1. Calls `provider.open(request)` to acquire a session.
/// 2. Stashes the session on the [RequestContext] under [kDbKey].
/// 3. Runs the inner handler.
/// 4. Calls `provider.close(session, ok: ...)` where `ok` is `true`
///    iff the response status code is `< 500` (a thrown
///    [HttpException] below 500 or a form validation error counts as
///    ok; any other exception does not).
///
/// If the request timed out, the handler may still be running; the
/// session then stays open until that work finishes and is closed
/// with `ok: false`.
///
/// Inside a controller / [Service] you reach the session via
/// `ctx.db<MySession>()`.
library gisila.runtime.db.db_session_middleware;

import 'dart:async';

import 'package:shelf/shelf.dart';

import '../context.dart';
import '../exceptions.dart';
import '../forms/form.dart' show FormValidationException;
import 'database_provider.dart';

/// `RequestContext.extra` key holding the per-request DB session.
const String kDbKey = 'gisila.db.session';

/// Wraps each request in [provider]'s session lifecycle.
///
/// Installed automatically by `GisilaApp.buildHandler` when
/// `AppConfig.database` is set; rarely composed by hand.
Middleware dbSessionMiddleware(DatabaseProvider<Object?> provider) {
  return (Handler inner) {
    return (Request request) async {
      final session = await provider.open(request);

      // Make sure a context exists; piggy-back on whatever
      // requestIdMiddleware materialised, or create a transient one.
      var ctx = RequestContext.maybeOf(request);
      ctx ??= RequestContext(requestId: 'db-anon', request: request);
      ctx.extra[kDbKey] = session;

      final req = request.change(context: <String, Object?>{
        ...request.context,
        kContextKey: ctx,
      });

      Future<void> close({required bool ok}) async {
        try {
          await provider.close(session, ok: ok);
        } catch (_) {
          // Swallow close failures - we don't want them to mask the
          // original response / exception. Providers that care should
          // log internally.
        }
      }

      var ok = false;
      try {
        final response = await inner(req);
        ok = response.statusCode < 500;
        return response;
      } on HttpException catch (e) {
        ok = e.statusCode < 500;
        rethrow;
      } on FormValidationException {
        ok = true;
        rethrow;
      } catch (_) {
        ok = false;
        rethrow;
      } finally {
        final abandoned = ctx.abandonedWork;
        if (abandoned.isEmpty) {
          await close(ok: ok);
        } else {
          // A timed-out handler may still be using the session: release
          // it only once that work is done, and never commit it.
          unawaited(Future.wait(abandoned).then((_) => close(ok: false)));
        }
      }
    };
  };
}
