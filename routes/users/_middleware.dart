import 'package:dart_frog/dart_frog.dart';
import 'package:project_mega/middlewares/middlewares.dart';

Handler middleware(Handler handler) {
  return handler.use(
    contentTypeMiddleware(
      [KContentType.form, KContentType.json, KContentType.urlEncoded],
    ),
  );
}
