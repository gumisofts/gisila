import 'package:dart_frog/dart_frog.dart';

Middleware authenticationMiddleware() =>
    (handler) => (context) => handler(context);
