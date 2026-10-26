/// Controller / route annotations consumed by the gisila generator.
///
/// These annotations are intentionally small and free-standing so user
/// code stays readable; the generator infers as much as it can from
/// parameter names and types.
///
/// Every route annotation accepts a `config: RouteConfig?` parameter
/// for per-route rate limiting, timeout, body size, content-type
/// whitelist, custom middleware, and declarative permissions. See
/// [RouteConfig] for the full list.
library gisila.annotations.controller;

import 'package:meta/meta_meta.dart';

import '../runtime/route_config.dart';

/// Marks a class as a gisila controller.
///
/// Every method annotated with one of [Get], [Post], [Put], [Patch],
/// [Delete], [Head], [Options] or the generic [Route] is registered as
/// a route on the framework's `shelf_router`.
///
/// The optional [path] is prepended to every method-level route path.
/// If omitted, methods carry their full paths themselves.
@Target({TargetKind.classType})
class Controller {
  const Controller([this.path = '']);

  /// Common prefix for every route in the controller, e.g. `/users`.
  final String path;
}

/// Applies a [RouteConfig] to every route in the annotated controller.
///
/// Method-level `config:` on individual route annotations is merged on
/// top of this class-level config; the class-level config is in turn
/// merged on top of `AppConfig.defaultRouteConfig`.
///
/// ```dart
/// @Controller('/admin')
/// @UseRouteConfig(RouteConfig(
///   rateLimit: RateLimitConfig(requestsPerMinute: 30),
///   timeout: Duration(seconds: 3),
/// ))
/// class AdminController { ... }
/// ```
@Target({TargetKind.classType})
class UseRouteConfig {
  const UseRouteConfig(this.config);
  final RouteConfig config;
}

/// Common base for HTTP-method annotations placed on controller methods.
///
/// The generator never instantiates [Route] directly; concrete
/// subclasses such as [Get] and [Post] carry the HTTP verb.
@Target({TargetKind.method})
class Route {
  const Route(
    this.method,
    this.path, {
    this.statusCode = 200,
    this.contentType = 'application/json',
    this.config,
  });

  final String method;
  final String path;

  /// HTTP status code used for the successful response when the handler
  /// returns a value (rather than a [shelf.Response] directly). For
  /// `POST` the generator defaults this to `201` unless overridden; for
  /// `DELETE` to `204`.
  final int statusCode;

  /// Content-type emitted for JSON-encoded responses.
  final String contentType;

  /// Per-route configuration overlay. Merged on top of
  /// `AppConfig.defaultRouteConfig` and any class-level
  /// `@UseRouteConfig`.
  final RouteConfig? config;
}

class Get extends Route {
  const Get(
    String path, {
    super.statusCode,
    super.contentType,
    super.config,
  }) : super(
          'GET',
          path,
        );
}

class Post extends Route {
  const Post(
    String path, {
    super.statusCode = 201,
    super.contentType,
    super.config,
  }) : super(
          'POST',
          path,
        );
}

class Put extends Route {
  const Put(
    String path, {
    super.statusCode,
    super.contentType,
    super.config,
  }) : super(
          'PUT',
          path,
        );
}

class Patch extends Route {
  const Patch(
    String path, {
    super.statusCode,
    super.contentType,
    super.config,
  }) : super(
          'PATCH',
          path,
        );
}

class Delete extends Route {
  const Delete(
    String path, {
    super.statusCode = 204,
    super.contentType,
    super.config,
  }) : super(
          'DELETE',
          path,
        );
}

class Head extends Route {
  const Head(
    String path, {
    super.statusCode,
    super.config,
  }) : super('HEAD', path);
}

class Options extends Route {
  const Options(
    String path, {
    super.statusCode = 204,
    super.config,
  }) : super('OPTIONS', path);
}
