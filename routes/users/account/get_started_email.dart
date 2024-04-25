import 'package:dart_frog/dart_frog.dart';
import 'package:project_mega/models/models.dart';
import 'package:project_mega/utils/exceptions/field_exceptions.dart';
import 'package:project_mega/utils/forms/api_validators.dart';
import 'package:project_mega/utils/http.dart';
import 'package:project_mega/utils/jwt.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method == HttpMethod.post) {
    return onRequestPost(context);
  }

  return Response(statusCode: statusCode405MethodNotAllowed);
}

Future<Response> onRequestPost(RequestContext context) async {
  try {
    final data = await form(
      context,
      fields: [
        FieldValidator<String>(
          name: 'email',
          isRequired: true,
          validator: (value) => RegExp(r'.+@.+\..+').hasMatch(value)
              ? null
              : 'Incorrect email format',
        ),
      ],
    );
    User? user;

    final email = data['email'] as String;

    user = await UserDb.get(where: (t) => t.email.equals(email));
    user ??= await UserDb.create(email: email);
    final access = JWTAuth.authenticate(user);
    return Response.json(
      body: {
        'user': user?.toJson(),
        'isRegistrationComplete': user?.firstName != null,
        'accessToken': access,
      },
    );
  } on FieldValidationException catch (e) {
    return Response.json(body: e.error);
  } catch (e) {
    return Response.json(
      body: {'detail': e.toString()},
    );
  }
}
