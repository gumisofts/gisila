import 'package:dart_frog/dart_frog.dart';
import 'package:project_mega/middlewares/middlewares.dart';

Handler middleware(Handler handler) =>
    handler.use(commonMiddleware()).use(authenticationMiddleware());

    // commonMiddleware(authenticationMiddleware(handler));
