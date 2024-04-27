import 'package:dart_frog/dart_frog.dart';
import 'package:project_mega/models/models.dart';
import 'package:project_mega/utils/utils.dart';

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
    var pass = await PasswordDb.get(where: (t) => t.userId.equals(user!.id!));

    pass ??= await PasswordDb.create(userId: user!.id!);

    final otp = generateSecureRandom();
    pass!.emailOtp = otp.toString();

    await pass.save();

    await SendMail.sendOtp(otp.toString(), user!);
    return Response.json(
      body: {
        'user': user.toJson(),
        'isRegistrationComplete': user.firstName != null,
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
