/// Controller / route annotations consumed by the gisila generator.
///
/// These annotations are intentionally small and free-standing so user
/// code stays readable; the generator infers as much as it can from
/// parameter names and types.
library gisila.annotations.controller;

import 'package:meta/meta_meta.dart';

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
}

class Get extends Route {
  const Get(
    String path, {
    int statusCode = 200,
    String contentType = 'application/json',
  }) : super('GET', path, statusCode: statusCode, contentType: contentType);
}

class Post extends Route {
  const Post(
    String path, {
    int statusCode = 201,
    String contentType = 'application/json',
  }) : super('POST', path, statusCode: statusCode, contentType: contentType);
}

class Put extends Route {
  const Put(
    String path, {
    int statusCode = 200,
    String contentType = 'application/json',
  }) : super('PUT', path, statusCode: statusCode, contentType: contentType);
}

class Patch extends Route {
  const Patch(
    String path, {
    int statusCode = 200,
    String contentType = 'application/json',
  }) : super('PATCH', path, statusCode: statusCode, contentType: contentType);
}

class Delete extends Route {
  const Delete(
    String path, {
    int statusCode = 204,
    String contentType = 'application/json',
  }) : super('DELETE', path, statusCode: statusCode, contentType: contentType);
}

class Head extends Route {
  const Head(String path, {int statusCode = 200})
      : super('HEAD', path, statusCode: statusCode);
}

class Options extends Route {
  const Options(String path, {int statusCode = 204})
      : super('OPTIONS', path, statusCode: statusCode);
}
