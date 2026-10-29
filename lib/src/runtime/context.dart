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

import 'dart:async';

import 'package:shelf/shelf.dart';

import 'auth/principal.dart';
import 'cache/cache_middleware.dart' show kCacheKey;
import 'cache/cache_provider.dart';
import 'db/db_session_middleware.dart' show kDbKey;

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

  /// Returns the per-request database session as `T`.
  ///
  /// Available only when `AppConfig.database` is configured; the
  /// framework's `dbSessionMiddleware` populates it before any
  /// controller runs. Throws [StateError] if no session was provided.
  T db<T>() {
    final session = extra[kDbKey];
    if (session == null) {
      throw StateError(
        'No database session attached to this request. Configure '
        'AppConfig.database before calling ctx.db<T>().',
      );
    }
    return session as T;
  }

  /// Returns the configured [CacheProvider] for this request.
  ///
  /// Available only when `AppConfig.cache` is configured; the
  /// framework's `cacheMiddleware` attaches it before any controller
  /// runs. Throws [StateError] if no cache was configured.
  ///
  /// ```dart
  /// final cached = await ctx.cache.get('user:$id');
  /// await ctx.cache.set('user:$id', json, ttl: Duration(minutes: 5));
  /// ```
  ///
  /// To obtain the concrete backend type use [cacheAs]:
  /// ```dart
  /// final redis = ctx.cacheAs<RedisCacheProvider>();
  /// ```
  CacheProvider get cache {
    final c = extra[kCacheKey];
    if (c == null) {
      throw StateError(
        'No cache provider attached to this request. Configure '
        'AppConfig.cache before calling ctx.cache.',
      );
    }
    return c as CacheProvider;
  }

  /// Returns the cache provider cast to the concrete type [T].
  ///
  /// Throws [StateError] if no cache is configured, or [TypeError] if
  /// the configured provider is not a subtype of [T].
  T cacheAs<T extends CacheProvider>() => cache as T;

  /// Cancelled when the framework gives up on this request (it timed
  /// out). Long-running handlers should check
  /// [CancellationToken.isCancelled] or call
  /// [CancellationToken.throwIfCancelled] between steps: once
  /// cancelled, the client already has its `504` and any database
  /// work is rolled back.
  CancellationToken get cancellation =>
      extra.putIfAbsent(kCancellationKey, CancellationToken.new)
          as CancellationToken;

  /// Records handler work still running after the framework answered
  /// the request (a timeout). Resource owners such as the database
  /// session middleware wait for it before releasing what the handler
  /// may still be using.
  void addAbandonedWork(Future<Object?> work) {
    final list = extra.putIfAbsent(kAbandonedWorkKey, () => <Future<void>>[])
        as List<Future<void>>;
    // Errors from abandoned work have nowhere to go; swallow them so
    // they don't surface as unhandled.
    list.add(work.then((_) {}, onError: (Object _) {}));
  }

  /// Work registered via [addAbandonedWork].
  List<Future<void>> get abandonedWork =>
      (extra[kAbandonedWorkKey] as List<Future<void>>?) ??
      const <Future<void>>[];

  /// Returns an instance of service [T] for this request.
  ///
  /// The lookup is delegated to a resolver installed by [GisilaApp]
  /// (which keeps a per-request cache so the same logical service
  /// isn't materialised twice). Throws [StateError] if no resolver is
  /// installed or no factory is registered for `T`.
  T service<T extends Object>() {
    final resolver = extra[kServiceResolverKey];
    if (resolver == null) {
      throw StateError(
        'No service resolver attached to this request. Make sure the '
        'request flows through GisilaApp.buildHandler() and that you '
        'registered services with app.registerService<T>(factory).',
      );
    }
    return (resolver as Object Function(RequestContext, Type))(this, T) as T;
  }

  /// The app-wide singleton registered as [T] (see
  /// `GisilaApp.registerSingleton`). Throws [StateError] if none is
  /// registered or the app hasn't started.
  T singleton<T extends Object>() {
    final resolver = extra[kSingletonResolverKey];
    if (resolver == null) {
      throw StateError(
        'No singleton resolver attached to this request. Make sure the '
        'request flows through GisilaApp.buildHandler().',
      );
    }
    return (resolver as Object Function(Type))(T) as T;
  }

  /// Reads the [RequestContext] previously attached to [request], or
  /// `null` if none.
  static RequestContext? maybeOf(Request request) {
    final ctx = request.context[kContextKey];
    return ctx is RequestContext ? ctx : null;
  }
}

/// `RequestContext.extra` key under which [GisilaApp] stashes the
/// service resolver function.
const String kServiceResolverKey = 'gisila.service_resolver';

/// `RequestContext.extra` key under which [GisilaApp] stashes the
/// singleton resolver function.
const String kSingletonResolverKey = 'gisila.singleton_resolver';

/// `RequestContext.extra` key holding the request's [CancellationToken].
const String kCancellationKey = 'gisila.cancellation';

/// `RequestContext.extra` key holding abandoned handler work.
const String kAbandonedWorkKey = 'gisila.abandoned_work';

/// Thrown by [CancellationToken.throwIfCancelled].
class RequestCancelledException implements Exception {
  const RequestCancelledException();

  @override
  String toString() => 'RequestCancelledException: request was cancelled';
}

/// Cooperative cancellation signal for one request.
class CancellationToken {
  final Completer<void> _completer = Completer<void>();

  bool get isCancelled => _completer.isCompleted;

  /// Completes when the request is cancelled.
  Future<void> get whenCancelled => _completer.future;

  void cancel() {
    if (!_completer.isCompleted) _completer.complete();
  }

  void throwIfCancelled() {
    if (isCancelled) throw const RequestCancelledException();
  }
}
