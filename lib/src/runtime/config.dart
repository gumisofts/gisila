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
import 'metrics/metrics_middleware.dart';
import 'middleware/compression.dart';
import 'middleware/cors.dart';
import 'middleware/etag.dart';
import 'middleware/rate_limit.dart';
import 'middleware/security_headers.dart';
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
    this.securityHeaders = const SecurityHeadersConfig(),
    this.compression,
    this.etags,
    this.rateLimit,
    this.rateLimitStore,
    this.trustedProxies = const <String>{'127.0.0.1', '::1'},
    this.defaultRouteConfig = RouteConfig.empty,
    this.errorHandler,
    this.serverHeader = '',
    this.healthCheckPath,
    this.healthCheck,
    this.metrics,
    this.poweredByHeader = false,
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

  /// Browser security headers added to every response (HSTS, nosniff,
  /// `X-Frame-Options`, `Referrer-Policy`, a locked-down CSP on non-HTML
  /// responses). On by default; `null` turns them all off, and each field
  /// of [SecurityHeadersConfig] can be turned off on its own.
  final SecurityHeadersConfig? securityHeaders;

  /// If non-null, responses are gzipped for clients that accept it (see
  /// [compressionMiddleware]). Leave it off when a reverse proxy already
  /// compresses.
  final CompressionConfig? compression;

  /// If non-null, successful `GET` responses get an `ETag` and repeat
  /// requests with a matching `If-None-Match` get `304 Not Modified`.
  final EtagConfig? etags;

  /// If non-null, the rate-limit middleware is registered with this
  /// config.
  final RateLimitConfig? rateLimit;

  /// Where the app-wide and per-route rate limiters keep their buckets.
  /// Null gives each limiter its own in-memory store, so every isolate or
  /// process allows the full rate; pass a shared store (e.g. Redis-backed)
  /// to enforce one limit across all of them.
  final RateLimitStore? rateLimitStore;

  /// Reverse proxies (exact IPs or CIDR ranges) allowed to report the
  /// client address via `X-Forwarded-For`. Used by the rate limiter's
  /// default key (see [clientAddress]); empty means the header is
  /// always ignored.
  ///
  /// Defaults to loopback, which covers a reverse proxy (nginx, Caddy)
  /// on the same host: only local processes can connect from there.
  /// Add your load balancer's range when it lives elsewhere, e.g.
  /// `{'127.0.0.1', '::1', '10.0.0.0/8'}`.
  final Set<String> trustedProxies;

  /// Baseline per-route configuration applied to every generated
  /// route, before merging class-level and method-level overrides.
  ///
  /// Typical use: configure a default per-route timeout or rate limit
  /// that applies unless an individual route overrides it.
  final RouteConfig defaultRouteConfig;

  /// Maps an uncaught exception to a Shelf response. Defaults to
  /// [HttpException]-aware behaviour.
  final ErrorHandler? errorHandler;

  /// Path answering liveness probes (`GET`, no auth, before every other
  /// middleware except the request id), e.g. `'/healthz'`. Null (the
  /// default) serves none. It answers `{"status":"ok"}`, or `503` with
  /// `{"status":"unavailable"}` when [healthCheck] returns false or throws.
  final String? healthCheckPath;

  /// Optional readiness check for [healthCheckPath], e.g. a database ping.
  final Future<bool> Function()? healthCheck;

  /// If non-null, request metrics are recorded in `GisilaApp.metrics` and
  /// served in the Prometheus format at [MetricsConfig.path] (by default
  /// only to direct loopback connections).
  final MetricsConfig? metrics;

  /// Value of the `Server` header; empty (the default) sends none, so the
  /// framework and its version aren't advertised.
  final String serverHeader;

  /// Send an `X-Powered-By: gisila` header on every response. Off by
  /// default.
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
