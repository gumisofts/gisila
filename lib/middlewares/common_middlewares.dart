// ignore_for_file: public_member_api_docs

import 'package:dart_frog/dart_frog.dart';
import 'package:project_mega/utils/http.dart';

final acceptedContentType = [
  'application/json',
  'application/x-www-form-urlencoded',
  'multipart/form-data',
  'text/plain',
];

final contentMap = {
  'application/json': KContentType.json,
  'application/x-www-form-urlencoded': KContentType.urlEncoded,
  'multipart/form-data': KContentType.form,
  'text/plain': KContentType.plainText,
};

Middleware commonMiddleware() => (handler) => (context) async {
      final response = await handler(context);

      return response;
    };

enum KContentType { json, plainText, form, urlEncoded }

Middleware contentTypeMiddleware(List<KContentType> types) =>
    (handler) => (context) async {
          if (![HttpMethod.patch, HttpMethod.post, HttpMethod.put]
              .contains(context.request.method)) {
            return await handler(context);
          }
          if (context.request.headers['content-type'] == null) {
            return Response(statusCode: statusCode415UnSupportedMediaType);
          }
          final contentType = contentMap[context
              .request.headers['content-type']!
              .replaceAll(RegExp(';.+'), '')];

          if (contentType != null && !contentMap.values.contains(contentType)) {
            return Response.json(
              body: {'detail': 'Invalid content type'},
              statusCode: statusCode415UnSupportedMediaType,
            );
          }

          final response = await handler.use(
            provider<KContentType>((context) => contentType!),
          )(context);

          return response;
        };
Handler httpMethodMiddleware(Handler handler, List<HttpMethod> methods) {
  return (context) async {
    if (!methods.contains(context.request.method)) {
      return Response.json(
        body: {'detail': 'method not allowed'},
        statusCode: 415,
      );
    }

    final response = await handler(context);

    return response;
  };
}

Middleware testMiddleWare() {
  return (handler) => (context) {
        return Response();
      };
}
