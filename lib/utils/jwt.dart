import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:project_mega/models/models.dart';

class JWTAuth {
  static String authenticate(User? user) {
    return JWT(
      {
        'id': user?.id ?? 'not valid',
        'phoneNumber': user?.phoneNumber ?? 'empty',
        'email': user?.email ?? 'nott',
      },
      jwtId: '',
    ).sign(
      SecretKey('key'),
      expiresIn: const Duration(days: 30),
    );
  }

  static bool verify(String token) {
    try {
      JWT.verify(token, SecretKey('key'));

      return true;
    } catch (_) {
      return false;
    }
  }

  static Map<String, dynamic> decode(String token) {
    final data = JWT.decode(token);

    return data.payload as Map<String, dynamic>;
  }

  static Map<String, dynamic>? decodeAndVerify(String token) =>
      verify(token) ? decode(token) : null;
}

// void main(List<String> args) async {
//   final user = await UserDb.get(where: (t) => t.id.equals(3));

//   print(user?.firstName);
//   print(user);
//   user!.firstName = null;
//   await user.save();
  // final data = JWTAuth.decode(
  //   'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6NCwicGhvbmVOdW1iZXIiOiI3MjgwMDAwMDAiLCJlbWFpbCI6Im5vdHQiLCJpYXQiOjE3MTM5NzU1MDcsImV4cCI6MTcxNjU2NzUwNywianRpIjoiIn0.uXrUlJX8xM7b7zz_OU4cTFmrDZE0PejrdcfCZW1BeEQ',
  // );
// }
