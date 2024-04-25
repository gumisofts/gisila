import 'package:dart_frog/dart_frog.dart';
import 'package:project_mega/models/models.dart';
import 'package:project_mega/utils/jwt.dart';

Middleware authenticationMiddleware() => (handler) => (context) async {
      var auth = context.request.headers['auth'] ?? '';
      final splitted = auth.split(RegExp(r'\s+'));

      if (splitted.length != 2) {
        return handler.use(provider<User?>((context) => null))(context);
      }
      if (splitted.first != 'Bearer') {
        return handler.use(provider<User?>((context) => null))(context);
      }
      auth = splitted.last;
      final data = JWTAuth.decodeAndVerify(auth) ?? <String, String>{};
      final userId = data['id'] as int?;
      User? user;
      if (userId != null) {
        user = await UserDb.get(where: (t) => t.id.equals(userId));
      }

      return handler.use(provider<User?>((context) => user))(context);
    };
