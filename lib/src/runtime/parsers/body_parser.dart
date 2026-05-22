/// Content-type-aware request body parsing.
///
/// Three helpers, each callable by hand from a controller and (more
/// importantly) by the build-time generator depending on the body
/// parameter's declared type:
///
/// | Helper          | Returns                                | Accepts                                                              |
/// | --------------- | -------------------------------------- | -------------------------------------------------------------------- |
/// | [readJsonBody]  | decoded JSON value                     | `application/json` only                                              |
/// | [readFormBody]  | [FormData]                             | `application/x-www-form-urlencoded` or `multipart/form-data`         |
/// | [readBody]      | `Map<String, dynamic>` / [FormData] / decoded JSON | any of the above; dispatches by `Content-Type` |
///
/// All three throw [BadRequestException] on a missing required body,
/// a malformed payload, or an unsupported content type - the
/// framework's global error mapper turns it into a uniform `400`
/// envelope.
library gisila.runtime.parsers.body_parser;

import 'dart:io';

import 'package:shelf/shelf.dart';

import '../codec.dart' show BadRequestException, readJsonBody;
import 'form_data.dart';

export '../codec.dart' show readJsonBody;

/// Decoded request body in the union shape consumers actually care
/// about:
///
/// * `Map<String, dynamic>` for JSON objects and form-urlencoded
///   bodies.
/// * `List<dynamic>` for JSON arrays.
/// * [FormData] for `multipart/form-data` (itself a `Map<String,
///   Object>` via `MapMixin`).
/// * `String`, `num`, `bool` for JSON primitives.
/// * `null` when the body is absent and `required: false`.
typedef DecodedBody = Object?;

/// Reads the request body and decodes it according to the
/// `Content-Type`. Mirrors the dispatch logic used by the generated
/// handler code, but is also fine to call by hand from a controller
/// method that takes a raw `Request`.
///
/// * `application/json` → returns whatever `jsonDecode` produces.
/// * `application/x-www-form-urlencoded` → returns a
///   `Map<String, String>` cast as `Map<String, dynamic>`.
/// * `multipart/form-data` → returns a [FormData].
/// * empty body → returns `null` if `required` is `false`, otherwise
///   throws [BadRequestException].
/// * any other content type → throws [BadRequestException]
///   (`415`-ish, but rendered as `400` for consistency with the rest
///   of the framework).
Future<DecodedBody> readBody(Request request, {bool required = true}) async {
  final raw = request.headers[HttpHeaders.contentTypeHeader];
  final mime = raw?.split(';').first.trim().toLowerCase();

  switch (mime) {
    case null:
    case '':
      // No content-type at all: still respect `required` so empty
      // POSTs are handled the same way as the JSON-only helper.
      if (required) {
        throw BadRequestException(
          'Request body is required (missing Content-Type header).',
        );
      }
      return null;

    case 'application/json':
    case 'application/vnd.api+json':
    case 'text/json':
      return readJsonBody(request, required: required);

    case 'application/x-www-form-urlencoded':
    case 'multipart/form-data':
      final form = await readFormBody(request, required: required);
      return form;

    default:
      throw BadRequestException(
        'Unsupported Content-Type "$mime". Expected one of: '
        'application/json, application/x-www-form-urlencoded, '
        'multipart/form-data.',
      );
  }
}

/// Reads the body strictly as form data (urlencoded or multipart).
///
/// Returns `null` only when the body is absent **and**
/// `required` is `false`. Throws [BadRequestException] on any other
/// content type.
Future<FormData?> readFormBody(
  Request request, {
  bool required = true,
}) async {
  final raw = request.headers[HttpHeaders.contentTypeHeader];
  if (raw == null || raw.isEmpty) {
    if (required) {
      throw BadRequestException(
        'Request body is required '
        '(expected multipart/form-data or application/x-www-form-urlencoded).',
      );
    }
    return null;
  }
  return parseFormData(
    headers: request.headers,
    body: request.readAsString,
    bytes: request.read,
  );
}
