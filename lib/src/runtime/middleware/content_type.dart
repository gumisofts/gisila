/// Allowed-content-type middleware.
///
/// Inspired by the same-named helper used in `bita_backends`: rejects
/// `POST` / `PUT` / `PATCH` requests whose `Content-Type` (sans
/// parameters) isn't in [contentTypes] with a `415 Unsupported Media
/// Type` JSON envelope. Other verbs pass through.
library gisila.runtime.middleware.content_type;

import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

/// Default whitelist - the three content types the framework's body
/// parser knows how to decode.
const defaultAllowedContentTypes = <String>{
  'application/json',
  'application/x-www-form-urlencoded',
  'multipart/form-data',
};

/// Returns a [Middleware] that rejects unsupported request body
/// content types. Set [contentTypes] to whatever your service is
/// prepared to decode.
///
/// ```dart
/// app.use(allowedContentTypesMiddleware());
/// // or only allow JSON:
/// app.use(allowedContentTypesMiddleware(contentTypes: {'application/json'}));
/// ```
Middleware allowedContentTypesMiddleware({
  Set<String> contentTypes = defaultAllowedContentTypes,
  Set<String> guardedMethods = const {'POST', 'PUT', 'PATCH'},
}) {
  final normalised = contentTypes.map((s) => s.toLowerCase()).toSet();
  return (Handler inner) {
    return (Request request) async {
      if (!guardedMethods.contains(request.method)) {
        return inner(request);
      }
      final ct = request.headers[HttpHeaders.contentTypeHeader]
          ?.split(';')
          .first
          .trim()
          .toLowerCase();
      if (ct == null || !normalised.contains(ct)) {
        return Response(
          415,
          body: jsonEncode(<String, Object?>{
            'error': <String, Object?>{
              'status': 415,
              'code': 'unsupported_media_type',
              'message': ct == null
                  ? 'Missing Content-Type header'
                  : 'Unsupported Content-Type "$ct"',
              'details': <String, Object?>{
                'allowed': normalised.toList(),
              },
            },
          }),
          headers: const {
            'content-type': 'application/json; charset=utf-8',
          },
        );
      }
      return inner(request);
    };
  };
}
