import 'dart:async';
import 'package:dart_frog/dart_frog.dart';
import 'package:project_mega/models/schema.dart';
import 'package:project_mega/utils/exceptions/field_exceptions.dart';
import 'package:project_mega/utils/http.dart';
import 'package:project_mega/utils/validators/api_validators.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method == HttpMethod.post) {
    return onRequestPost(context);
  }
  if (context.request.method == HttpMethod.get) {
    return onRequestGet(context);
  }
  return Response(statusCode: statusCode405MethodNotAllowed);
}

Future<Response> onRequestPost(RequestContext context) async {
  try {
    final data = await fieldValidatorWrapper(
      context,
      fields: [
        FieldValidator<String>(
          name: 'firstName',
          isRequired: true,
          validator: (value) {
            if (value.trim().isEmpty) {
              return 'firstName cannot be empty';
            }
            return null;
          },
        ),
        FieldValidator<String>(
          name: 'lastName',
          isRequired: true,
          validator: (value) {
            if (value.trim().isEmpty) {
              return 'lastName cannot be empty';
            }
            return null;
          },
        ),
        FieldValidator<String>(
          name: 'phone',
          validator: (value) {
            if (!RegExp(r'9\d{8}').hasMatch(value)) {
              return 'Invalid phone number format';
            }
            return null;
          },
        ),
        FieldValidator<String>(
          name: 'email',
          validator: (value) {
            if (!RegExp(r'.+@.+\..{3}').hasMatch(value)) {
              return 'Invalid email format';
            }
            return null;
          },
        ),
      ],
    );
    final user = await UserDb.create(
      firstName: data['firstName'] as String,
      lastName: data['lastName'] as String?,
      email: data['email'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
    );
    // TThis is to test
    return Response.json(body: user!.toJson());
  } on FieldValidationException catch (e) {
    return Response.json(body: e.error, statusCode: statusCode400BadRequest);
  }
}

// aa
Future<Response> onRequestGet(RequestContext contextaa) async {
  final users =
      await UserDb.filter(where: (t) => t.firstName.equals("1 or 1=1"));

  // await Future.delayed(const Duration(seconds: 40), () => '');

  return Response.json(
    body: users
        .map((e) => e.toJson(exclude: ['createdAt', 'updatedat']))
        .toList(),
  );
}
