/// Per-route configuration: everything that can vary between two
/// endpoints in the same controller.
///
/// Every route annotation (`@Get`, `@Post`, etc.) accepts a
/// `config: RouteConfig?` parameter. Whatever you put there is merged
/// with two other layers at code-gen time:
///
/// 1. `AppConfig.defaultRouteConfig` (app-wide baseline)
/// 2. class-level `@UseRouteConfig(RouteConfig(...))` (controller
///    defaults)
/// 3. the method-level `config:` argument (most specific - wins)
///
/// The resulting merged [RouteConfig] drives the per-route Shelf
/// pipeline that wraps the user controller method: rate limit,
/// content-type whitelist, timeout, body-size cap, AuthN/AuthZ, plus
/// any extra [middleware] the user supplied.
library gisila.runtime.route_config;

import 'package:shelf/shelf.dart';

import 'middleware/cors.dart';
import 'middleware/rate_limit.dart';

/// Per-route, declarative configuration.
///
/// All fields are nullable / empty by default so an unspecified
/// [RouteConfig] is a no-op overlay. Use the factory [merge] (or the
/// `+` operator) to layer configs on top of each other.
class RouteConfig {
  const RouteConfig({
    this.rateLimit,
    this.timeout,
    this.maxBodyBytes,
    this.contentTypes,
    this.cors,
    this.middleware = const <Middleware>[],
    this.requireAuth = false,
    this.permissions = const <String>{},
    this.anyPermission = const <String>{},
    this.roles = const <String>{},
    this.statusCode,
    this.isPublic = false,
  });

  /// Per-route rate limit. Overrides `AppConfig.rateLimit` for this
  /// route only.
  final RateLimitConfig? rateLimit;

  /// Per-route timeout. Overrides `AppConfig.requestTimeout`.
  final Duration? timeout;

  /// Per-route maximum request body size in bytes.
  final int? maxBodyBytes;

  /// Per-route whitelist of acceptable `Content-Type` values. When
  /// non-null, only `POST` / `PUT` / `PATCH` requests carrying one of
  /// these MIME types are accepted (returns `415` otherwise).
  final Set<String>? contentTypes;

  /// Per-route CORS overrides. Rarely needed; usually the app-wide
  /// `AppConfig.cors` suffices.
  final CorsConfig? cors;

  /// Extra Shelf middleware to apply, in the listed order, between the
  /// framework's built-in per-route middleware and the actual handler.
  final List<Middleware> middleware;

  /// `true` ⇒ the route requires an authenticated principal. Set
  /// indirectly when [permissions] / [anyPermission] / [roles] is
  /// non-empty.
  final bool requireAuth;

  /// All of these permissions must be present on the principal.
  final Set<String> permissions;

  /// At least one of these permissions must be present.
  final Set<String> anyPermission;

  /// At least one of these roles must be present.
  final Set<String> roles;

  /// Override the default success status code (200 for GET/PUT/PATCH,
  /// 201 for POST, 204 for DELETE/OPTIONS).
  final int? statusCode;

  /// Hard override: when `true`, all auth/permission guards are
  /// disabled regardless of class-level [requireAuth] or per-route
  /// permissions. Set by `@Public`.
  final bool isPublic;

  /// Empty config. Useful as the seed for [merge] folds.
  static const empty = RouteConfig();

  /// Returns a new [RouteConfig] whose fields take from [other] when
  /// set, falling back to this. Sets ([permissions] / [anyPermission]
  /// / [roles]) are unioned; lists ([middleware]) are concatenated.
  ///
  /// When [other.isPublic] is `true`, the merged config inherits the
  /// public flag and clears all auth/permission guards.
  RouteConfig merge(RouteConfig? other) {
    if (other == null) return this;
    if (other.isPublic) {
      return RouteConfig(
        rateLimit: other.rateLimit ?? rateLimit,
        timeout: other.timeout ?? timeout,
        maxBodyBytes: other.maxBodyBytes ?? maxBodyBytes,
        contentTypes: other.contentTypes ?? contentTypes,
        cors: other.cors ?? cors,
        middleware: <Middleware>[...middleware, ...other.middleware],
        requireAuth: false,
        permissions: const <String>{},
        anyPermission: const <String>{},
        roles: const <String>{},
        statusCode: other.statusCode ?? statusCode,
        isPublic: true,
      );
    }
    return RouteConfig(
      rateLimit: other.rateLimit ?? rateLimit,
      timeout: other.timeout ?? timeout,
      maxBodyBytes: other.maxBodyBytes ?? maxBodyBytes,
      contentTypes: other.contentTypes ?? contentTypes,
      cors: other.cors ?? cors,
      middleware: <Middleware>[...middleware, ...other.middleware],
      requireAuth: requireAuth || other.requireAuth,
      permissions: <String>{...permissions, ...other.permissions},
      anyPermission: <String>{...anyPermission, ...other.anyPermission},
      roles: <String>{...roles, ...other.roles},
      statusCode: other.statusCode ?? statusCode,
      isPublic: false,
    );
  }

  /// Shorthand for [merge].
  RouteConfig operator +(RouteConfig? other) => merge(other);

  /// Returns a copy with the given fields replaced. Use sparingly;
  /// [merge] is usually what you want.
  RouteConfig copyWith({
    RateLimitConfig? rateLimit,
    Duration? timeout,
    int? maxBodyBytes,
    Set<String>? contentTypes,
    CorsConfig? cors,
    List<Middleware>? middleware,
    bool? requireAuth,
    Set<String>? permissions,
    Set<String>? anyPermission,
    Set<String>? roles,
    int? statusCode,
    bool? isPublic,
  }) {
    return RouteConfig(
      rateLimit: rateLimit ?? this.rateLimit,
      timeout: timeout ?? this.timeout,
      maxBodyBytes: maxBodyBytes ?? this.maxBodyBytes,
      contentTypes: contentTypes ?? this.contentTypes,
      cors: cors ?? this.cors,
      middleware: middleware ?? this.middleware,
      requireAuth: requireAuth ?? this.requireAuth,
      permissions: permissions ?? this.permissions,
      anyPermission: anyPermission ?? this.anyPermission,
      roles: roles ?? this.roles,
      statusCode: statusCode ?? this.statusCode,
      isPublic: isPublic ?? this.isPublic,
    );
  }

  /// `true` when this config carries any auth/permission requirements.
  bool get hasAuthGuards =>
      !isPublic &&
      (requireAuth ||
          permissions.isNotEmpty ||
          anyPermission.isNotEmpty ||
          roles.isNotEmpty);
}
