/// Per-request database session middleware.
///
/// When `AppConfig.database` is set, [GisilaApp] installs this
/// middleware early in the pipeline (after request-id, before the
/// router). For every request it:
///
/// 1. Calls `provider.open(request)` to acquire a session.
/// 2. Stashes the session on the [RequestContext] under [kDbKey].
/// 3. Runs the inner handler.
/// 4. In a `finally`, calls `provider.close(session, ok: ...)` where
///    `ok` is `true` iff the response status code is `< 500`.
///
/// Inside a controller / [Service] you reach the session via
/// `ctx.db<MySession>()`.
library gisila.runtime.db.db_session_middleware;

import 'package:shelf/shelf.dart';

import '../context.dart';
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

      var ok = false;
      try {
        final response = await inner(req);
        ok = response.statusCode < 500;
        return response;
      } catch (_) {
        ok = false;
        rethrow;
      } finally {
        try {
          await provider.close(session, ok: ok);
        } catch (_) {
          // Swallow close failures - we don't want them to mask the
          // original response / exception. Providers that care should
          // log internally.
        }
      }
    };
  };
}
