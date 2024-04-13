import 'package:dart_frog/dart_frog.dart';

final safeMethods = [
  HttpMethod.get,
  HttpMethod.head,
  HttpMethod.options,
];

const statusCode400BadRequest = 400;
const statusCode401UnAuthorized = 401;
const statusCode403Forbiden = 403;
const statusCode404NotFound = 404;
const statusCode405MethodNotAllowed = 405;
const statusCode415UnSupportedMediaType = 415;
const statusCode429ToManyRequest = 429;
const statusCode500InternalServerError = 500;
const statusCode200Ok = 200;
const statusCode201Created = 201;
const statusCode204NoContent = 204;
