/// Framework-defined exceptions.
///
/// Anything thrown inside a controller method that extends
/// [HttpException] is translated by the generated wrapper into a JSON
/// response with the matching status code. Other exceptions surface
/// through [AppConfig.errorHandler], defaulting to a generic `500`.
library gisila.runtime.exceptions;

/// Base class for exceptions that map directly to an HTTP status.
class HttpException implements Exception {
  HttpException(this.statusCode, this.message, {this.code, this.details});

  final int statusCode;
  final String message;

  /// Optional machine-readable error code (e.g. `"user_not_found"`).
  final String? code;

  /// Optional structured payload merged into the error envelope.
  final Map<String, Object?>? details;

  @override
  String toString() =>
      'HttpException($statusCode${code != null ? ' $code' : ''}: $message)';

  /// Renders the exception into the standard error JSON envelope.
  Map<String, Object?> toJson() => <String, Object?>{
        'error': <String, Object?>{
          'status': statusCode,
          'message': message,
          if (code != null) 'code': code,
          if (details != null) 'details': details,
        },
      };
}

class BadRequest extends HttpException {
  BadRequest(String message, {String? code, Map<String, Object?>? details})
      : super(400, message, code: code, details: details);
}

class Unauthorized extends HttpException {
  Unauthorized([String message = 'Authentication required'])
      : super(401, message, code: 'unauthorized');
}

class Forbidden extends HttpException {
  Forbidden([String message = 'Access denied'])
      : super(403, message, code: 'forbidden');
}

class NotFound extends HttpException {
  NotFound([String message = 'Resource not found'])
      : super(404, message, code: 'not_found');
}

class Conflict extends HttpException {
  Conflict(String message, {String? code, Map<String, Object?>? details})
      : super(409, message, code: code ?? 'conflict', details: details);
}

class TooManyRequests extends HttpException {
  TooManyRequests([String message = 'Too many requests'])
      : super(429, message, code: 'too_many_requests');
}

class InternalServerError extends HttpException {
  InternalServerError([String message = 'Internal server error'])
      : super(500, message, code: 'internal_error');
}

/// Application-level exception that maps to a custom status code and
/// an arbitrary JSON body.
///
/// Use this when none of the named subclasses fits and you want full
/// control over the rendered envelope:
///
/// ```dart
/// throw EndpointException(
///   statusCode: 422,
///   body: {'detail': 'Order rejected by payment processor'},
/// );
/// ```
///
/// Subclassed by [HttpException], so the framework's error middleware
/// catches it via the same code path as the named exceptions.
class EndpointException extends HttpException {
  EndpointException({
    required int statusCode,
    Map<String, Object?>? body,
    String? message,
    String? code,
  })  : _body = body,
        super(
          statusCode,
          message ?? _bodyDetail(body) ?? 'Endpoint error',
          code: code,
          details: body,
        );

  final Map<String, Object?>? _body;

  /// Returns the user-supplied body when available, otherwise the
  /// standard `{error: {...}}` envelope built by [HttpException].
  @override
  Map<String, Object?> toJson() {
    if (_body != null) return _body;
    return super.toJson();
  }

  static String? _bodyDetail(Map<String, Object?>? body) {
    if (body == null) return null;
    final detail = body['detail'] ?? body['message'];
    return detail?.toString();
  }
}
