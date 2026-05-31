/// Framework-wide configuration.
library gisila.runtime.config;

import 'package:shelf/shelf.dart';

import 'auth/authenticator.dart';
import 'auth/permission_resolver.dart';
import 'cache/cache_provider.dart';
import 'db/database_provider.dart';
import 'db/db_error_mapper.dart';
import 'exceptions.dart';
import 'logging/log_event.dart';
import 'logging/logger.dart';
import 'middleware/cors.dart';
import 'middleware/rate_limit.dart';
import 'route_config.dart';

/// Translates an uncaught exception thrown by a controller method (or
/// the framework itself) into a Shelf response.
typedef ErrorHandler = Response Function(Object error, StackTrace stack);

/// Application-wide configuration. Pass to [GisilaApp].
class AppConfig {
  AppConfig({
    Logger? logger,
    this.logLevel = LogLevel.info,
    this.logFormat = LogFormat.text,
    this.logRequests = true,
    this.logRequestBody = false,
    this.logResponseBody = false,
    this.authenticator = const NullAuthenticator(),
    this.permissionResolver = const ClaimsPermissionResolver(),
    this.database,
    this.dbErrorMapper,
    this.cache,
    this.requestIdHeader = 'X-Request-Id',
    this.cors,
    this.rateLimit,
    this.defaultRouteConfig = RouteConfig.empty,
    this.errorHandler,
    this.serverHeader = 'gisila/0.2.0',
    this.poweredByHeader = true,
    this.requestTimeout,
    this.maxRequestBodyBytes,
    this.extra = const <String, Object?>{},
  }) : _logger = logger;

  /// Pluggable logger sink. Defaults to a [ConsoleLogger] with the
  /// configured [logLevel] / [logFormat].
  Logger get logger =>
      _logger ??= ConsoleLogger(level: logLevel, format: logFormat);
  Logger? _logger;
  set logger(Logger value) => _logger = value;

  /// Minimum severity emitted by the default console logger. Ignored
  /// if a custom [logger] is supplied.
  final LogLevel logLevel;

  /// Format used by the default console logger.
  final LogFormat logFormat;

  /// Whether the per-request access log middleware is installed.
  final bool logRequests;

  /// Capture the (potentially large) raw request body in the access
  /// log. Off by default.
  final bool logRequestBody;
  final bool logResponseBody;

  /// Authentication strategy. Defaults to a [NullAuthenticator] which
  /// rejects every guarded route.
  final Authenticator authenticator;

  /// How permissions/roles are checked once the principal is known.
  final PermissionResolver permissionResolver;

  /// Optional database provider. When set, the framework runs a
  /// per-request session middleware that acquires a session via
  /// [DatabaseProvider.open] before the controller runs and commits /
  /// rolls back on the response status code.
  ///
  /// Inside a controller / [Service] you reach the session through
  /// `ctx.db<MySession>()`.
  final DatabaseProvider<Object?>? database;

  /// Translates driver-specific database errors (e.g. Postgres
  /// `23xxx` constraint codes) into [HttpException]s before the
  /// default error envelope is rendered. Optional; when unset, raw
  /// errors fall through to the generic `500` mapper.
  final DbErrorMapper? dbErrorMapper;

  /// Optional cache provider. When set, the framework calls
  /// [CacheProvider.connect] on startup and [CacheProvider.disconnect]
  /// on shutdown, and attaches the provider to every [RequestContext]
  /// so controllers can reach it via `ctx.cache`.
  ///
  /// ```dart
  /// AppConfig(cache: InMemoryCacheProvider())
  /// ```
  ///
  /// Third-party backends (Redis, Memcached, …) implement
  /// [CacheProvider] and plug in here.
  final CacheProvider? cache;

  /// Header name used by the request-id middleware.
  final String requestIdHeader;

  /// If non-null, the CORS middleware is registered with this config.
  final CorsConfig? cors;

  /// If non-null, the rate-limit middleware is registered with this
  /// config.
  final RateLimitConfig? rateLimit;

  /// Baseline per-route configuration applied to every generated
  /// route, before merging class-level and method-level overrides.
  ///
  /// Typical use: configure a default per-route timeout or rate limit
  /// that applies unless an individual route overrides it.
  final RouteConfig defaultRouteConfig;

  /// Maps an uncaught exception to a Shelf response. Defaults to
  /// [HttpException]-aware behaviour.
  final ErrorHandler? errorHandler;

  /// Value of the `Server` header (set to empty to disable).
  final String serverHeader;

  /// Send an `X-Powered-By': 'gisila` header on every response.
  final bool poweredByHeader;

  /// Hard ceiling for how long a single request may take. Requests
  /// that exceed this are aborted with `504 Gateway Timeout`.
  final Duration? requestTimeout;

  /// Reject requests with a body larger than this. `null` = unlimited
  /// (Shelf's default).
  final int? maxRequestBodyBytes;

  /// Arbitrary extra configuration available to user middleware.
  final Map<String, Object?> extra;
}
