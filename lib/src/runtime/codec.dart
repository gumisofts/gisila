/// Lightweight JSON helpers consumed by the generated handler code.
///
/// Kept deliberately tiny so the generated handlers stay readable.
library gisila.runtime.codec;

import 'dart:convert';

import 'package:shelf/shelf.dart';

import 'exceptions.dart';

/// Thrown when a request payload is malformed - missing required
/// parameter, wrong type, invalid JSON, etc.
///
/// Subclass of [HttpException] so the framework's global error mapper
/// turns it into a uniform `400` JSON envelope without each generated
/// handler having to catch it explicitly.
class BadRequestException extends HttpException {
  BadRequestException(String message)
      : super(400, message, code: 'bad_request');
}

const _jsonHeaders = <String, String>{
  'content-type': 'application/json; charset=utf-8',
};

/// JSON-encodes [body] (calling `toJson()` recursively if present) and
/// returns a Shelf [Response] with the given [statusCode].
Response jsonResponse({
  Object? body,
  int statusCode = 200,
  Map<String, String>? extraHeaders,
}) {
  final encoded = jsonEncode(_normaliseForJson(body));
  return Response(
    statusCode,
    body: encoded,
    headers: <String, String>{
      ..._jsonHeaders,
      if (extraHeaders != null) ...extraHeaders,
    },
  );
}

/// Empty body response, useful for `204 No Content` / `205 Reset
/// Content`.
Response emptyResponse({int statusCode = 204}) =>
    Response(statusCode, headers: const {'content-length': '0'});

/// Reads the request body and decodes it as JSON.
///
/// Throws [BadRequestException] if [required] is `true` and the body is
/// missing/empty, or if the JSON is malformed.
Future<Object?> readJsonBody(Request request, {bool required = true}) async {
  final raw = await request.readAsString();
  if (raw.isEmpty) {
    if (required) {
      throw BadRequestException('Request body is required.');
    }
    return null;
  }
  try {
    return jsonDecode(raw);
  } on FormatException catch (e) {
    throw BadRequestException('Malformed JSON body: ${e.message}');
  }
}

/// Parses a raw query / path / header value into the requested Dart
/// type.
///
/// Supports `String`, `int`, `double`, `num`, `bool`, `DateTime` and
/// their nullable variants. Throws [BadRequestException] on missing
/// required parameters or invalid formats.
T coerce<T>(String? value, String paramName, {required bool required}) {
  final isNullable = null is T;
  // `?page=` means "not given" for anything but a string; an empty value
  // can't be parsed as a number, bool or date anyway.
  final isString = T == String || T == _typeOf<String?>();
  if (value == null || (value.isEmpty && !isString)) {
    if (required && !isNullable) {
      throw BadRequestException('Missing required parameter: $paramName');
    }
    return null as T;
  }
  try {
    if (isString) return value as T;
    if (T == int || T == _typeOf<int?>()) return int.parse(value) as T;
    if (T == double || T == _typeOf<double?>()) return double.parse(value) as T;
    if (T == num || T == _typeOf<num?>()) return num.parse(value) as T;
    if (T == bool || T == _typeOf<bool?>()) {
      switch (value.toLowerCase()) {
        case 'true':
        case '1':
        case 'yes':
          return true as T;
        case 'false':
        case '0':
        case 'no':
          return false as T;
        default:
          throw BadRequestException(
              'Parameter "$paramName" must be a boolean (got "$value").');
      }
    }
    if (T == DateTime || T == _typeOf<DateTime?>()) {
      return DateTime.parse(value) as T;
    }
  } on FormatException catch (e) {
    throw BadRequestException(
        'Parameter "$paramName" is not a valid ${T.toString()}: ${e.message}');
  }
  throw BadRequestException(
      'Unsupported parameter type ${T.toString()} for "$paramName".');
}

Type _typeOf<T>() => T;

/// Recursively converts a value into something `jsonEncode` can
/// serialise: calls `toJson()` on user types, walks lists / maps.
Object? _normaliseForJson(Object? value) {
  if (value == null) return null;
  if (value is String || value is num || value is bool) return value;
  if (value is DateTime) return value.toIso8601String();
  if (value is Iterable) {
    return value.map(_normaliseForJson).toList(growable: false);
  }
  if (value is Map) {
    return <String, Object?>{
      for (final entry in value.entries)
        entry.key.toString(): _normaliseForJson(entry.value),
    };
  }
  // Anything else: trust toJson() if it exists; an enum without one is
  // its name ("red", not "Color.red"); otherwise fall back to toString().
  try {
    final dynamic dyn = value;
    return _normaliseForJson(dyn.toJson() as Object?);
  } on NoSuchMethodError {
    if (value is Enum) return value.name;
    return value.toString();
  }
}
