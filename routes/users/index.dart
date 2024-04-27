import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:project_mega/models/models.dart';
import 'package:project_mega/utils/forms/field_exceptions.dart';
import 'package:project_mega/utils/forms/form_validators.dart';
import 'package:project_mega/utils/http.dart';

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
    final data = await form(
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
    // final user = User.fromJson(data);
    final user = await UserDb.create();
    return Response.json(body: user);
  } on FieldValidationException catch (e) {
    return Response.json(body: e.error, statusCode: statusCode400BadRequest);
  }
}

Future<Response> onRequestGet(RequestContext context) async {
  final queryparams = context.request.url.queryParameters;
  // Operation? operation;

  // for (final entry in queryparams.entries) {
  //   if (!UserExt.columns.contains(entry.key)) continue;
  //   final op = Operation(entry.key, Operator.eq, entry.value);
  //   operation ??= op;
  //   operation = operation & op;
  // }
  // final users = await UserExt.filter(operation);

  return Response.json();
}
