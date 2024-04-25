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
          name: 'phoneNumber',
          isRequired: true,
          validator: (value) => RegExp(r'(7|9)\d{8}').hasMatch(value)
              ? null
              : 'Incorrect phone format',
        ),
      ],
    );
    late User? user;

    final phoneNumber = data['phoneNumber'] as String;

    user = await UserDb.get(where: (t) => t.phoneNumber.equals(phoneNumber));
    user ??= await UserDb.create(phoneNumber: phoneNumber);
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
    return Response.json(body: {'detail': e.toString()});
  }
}
