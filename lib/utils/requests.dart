import 'dart:async';
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';

Future<Response> requestMethodRouter(
  RequestContext context, {
  Future<Response> Function(RequestContext context)? get,
  Future<Response> Function(RequestContext context)? post,
  Future<Response> Function(RequestContext context)? delete,
  Future<Response> Function(RequestContext context)? put,
  Future<Response> Function(RequestContext context)? patch,
  Future<Response> Function(RequestContext context)? head,
  Future<Response> Function(RequestContext context)? options,
}) async {
  switch (context.request.method) {
    case HttpMethod.delete:
      if (delete != null) return delete(context);

    case HttpMethod.get:
      if (get != null) return get(context);
    case HttpMethod.head:
      if (head != null) return head(context);
    case HttpMethod.options:
      if (options != null) return options(context);
    case HttpMethod.patch:
      if (patch != null) return patch(context);
    case HttpMethod.post:
      if (post != null) return post(context);
    case HttpMethod.put:
      if (put != null) return put(context);
  }

  return Response.json(statusCode: HttpStatus.methodNotAllowed);
}
