/// Pluggable database session provider.
///
/// The framework owns the per-request session lifecycle: it asks the
/// provider for a session before the controller runs and tells it to
/// commit / rollback after the response is produced.
///
/// Inside a controller / [Service] you reach the session via
/// `ctx.db<MySession>()` - the type parameter is whatever your
/// provider yields (e.g. a `gisila_orm` `Database`, a `postgres`
/// `Connection`, a transaction wrapper, …).
///
/// Implementations are package-specific and live in user code; see the
/// `open-delivery` integration for a `gisila_orm` example.
library gisila.runtime.db.database_provider;

import 'package:shelf/shelf.dart';

/// Acquires and releases per-request database sessions.
///
/// `S` is the concrete session type the provider hands out (your ORM
/// `Database`, a raw connection, a transaction object, …).
///
/// The framework invokes [open] once per request before the controller
/// runs, stashes the result on `RequestContext`, and calls [close] in
/// a `finally` block once the controller finishes. `ok` indicates
/// whether the request completed without a server error - providers
/// that wrap each request in a transaction should `commit` when `ok`
/// is `true` and `rollback` otherwise.
abstract class DatabaseProvider<S> {
  const DatabaseProvider();

  /// Acquires a session for [request]. May reuse a pooled connection
  /// or open a fresh one - it's the provider's call.
  Future<S> open(Request request);

  /// Releases the session previously returned from [open]. The
  /// framework passes [ok] = `true` for responses with status
  /// `< 500`, `false` otherwise. Providers that implement
  /// per-request transactions should `commit` / `rollback`
  /// accordingly.
  Future<void> close(S session, {required bool ok});

  /// Releases the provider itself (a connection pool, say). Called by
  /// `GisilaApp.stop()` after in-flight requests have finished. No-op by
  /// default.
  Future<void> dispose() async {}
}
