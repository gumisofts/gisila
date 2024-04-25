import 'dart:async';
import 'package:dart_frog/dart_frog.dart';
import 'package:project_mega/utils/utils.dart';

class EndPointException implements Exception {
  EndPointException({required this.error, required this.code});
  Map<String, dynamic> error;
  int code;
}

final unAuthorizedException = EndPointException(
  error: {'detail': 'Not authenticated'},
  code: statusCode401UnAuthorized,
);
final forbidenException = EndPointException(
  error: {
    'detail': "you don't have permission to do this action",
  },
  code: statusCode403Forbiden,
);

Future<Response> safeClosure(
  RequestContext context, {
  required Future<Response> Function() endpoint,
  required void Function() permission,
}) async {
  try {
    permission();
    return await endpoint();
  } on EndPointException catch (e) {
    return Response.json(statusCode: e.code, body: e.error);
  } catch (e) {
    return Response.json(body: {'detail': e.toString()});
  }
}
