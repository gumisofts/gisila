/// Per-request context.
///
/// A [RequestContext] is materialised by the framework before any
/// controller method runs. Controller methods may accept it as a
/// parameter (positionally or named) and the generator wires it
/// through:
///
/// ```dart
/// @Get('/me')
/// @RequireAuth()
/// Future<User> me(RequestContext ctx) async => repo.find(ctx.principal!.id);
/// ```
library gisila.runtime.context;

import 'package:shelf/shelf.dart';

import 'auth/principal.dart';

/// Shelf request "context key" used to stash the [RequestContext] on
/// a request via `request.change(context: ...)`.
const String kContextKey = 'gisila.context';

/// Per-request, framework-managed state.
class RequestContext {
  RequestContext({
    required this.requestId,
    required this.request,
    this.principal,
    Map<String, Object?>? extra,
  }) : extra = extra ?? <String, Object?>{};

  /// Unique id assigned by the request-id middleware.
  final String requestId;

  /// The underlying Shelf request. Headers, query params, etc.
  final Request request;

  /// Authenticated principal (if any). Populated by the framework after
  /// the [Authenticator] runs.
  Principal? principal;

  /// Open scratch space for app-level middleware / handlers.
  final Map<String, Object?> extra;

  /// Convenience: was the caller authenticated?
  bool get isAuthenticated => principal != null;

  /// Reads the [RequestContext] previously attached to [request], or
  /// `null` if none.
  static RequestContext? maybeOf(Request request) {
    final ctx = request.context[kContextKey];
    return ctx is RequestContext ? ctx : null;
  }
}
