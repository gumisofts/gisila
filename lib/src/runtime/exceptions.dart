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
