import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:project_mega/models/models.dart';
import 'package:project_mega/utils/utils.dart';
import 'package:test/test.dart';

Future<Response> onRequest(RequestContext context, String id) => safeClosure(
      context,
      endpoint: () async {
        final userId = int.parse(id);
        switch (context.request.method) {
          case HttpMethod.get:
            return onRequestGet(context, userId);
          case HttpMethod.patch:
            return onRequestPatch(context, userId);
          case HttpMethod.delete:
            return onRequestDelete(context, userId);
          // ignore: no_default_cases
          default:
            return Response.json(statusCode: HttpStatus.methodNotAllowed);
        }
      },
      permission: () {
        final contextUser = context.read<User?>();

        if (!contextUser.isAuthenticated) {
          throw unAuthorizedException;
        }

        if (contextUser!.id != int.parse(id)) {
          throw forbidenException;
        }
      },
    );

Future<Response> onRequestGet(RequestContext context, int id) async {
  final user = await UserDb.get(where: (t) => t.id.equals(id));
  if (user == null) {
    return Response.json(
      statusCode: statusCode404NotFound,
      body: {'detail': 'User not found'},
    );
  }

  return Response.json(body: user.toJson());
}

Future<Response> onRequestPatch(RequestContext context, int id) async {
  final user = await UserDb.get(where: (t) => t.id.equals(id));

  if (user == null) {
    return Response.json(
      body: 'user not found',
      statusCode: HttpStatus.notFound,
    );
  }

  final data = await form(
    context,
    fields: [
      FieldValidator<String?>(
        name: 'firstName',
        validator: (value) {
          if (value != null) return null;
          if (value!.length > 25) {
            return 'firstName is to long';
          }
          return null;
        },
      ),
      FieldValidator<String?>(
        name: 'lastName',
        validator: (value) {
          if (value != null) return null;
          if (value!.length > 25) {
            return 'lastName is to long';
          }
          return null;
        },
      ),
    ],
  );
  user
    ..firstName = (data['firstName'] as String?) ?? user.firstName
    ..lastName = (data['lastName'] as String?) ?? user.lastName;

  await user.save();

  return Response.json(body: user.toJson());
}

Future<Response> onRequestDelete(RequestContext context, int id) async {
  final user = await UserDb.get(where: (t) => t.id.equals(id));

  if (user == null) {
    return Response.json(
      body: 'User not found',
      statusCode: HttpStatus.notFound,
    );
  }

  prints('Deleting $user');

  await user.delete();
  return Response.json();
}
