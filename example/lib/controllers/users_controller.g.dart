// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'users_controller.dart';

// **************************************************************************
// ControllerGenerator
// **************************************************************************

// **************************************************
// gisila_orm: generated for UsersController
// **************************************************

extension UsersControllerGisilaWeb on UsersController {
  /// Registers every annotated route of this controller on
  /// [router] using [app] for authentication, permission
  /// checks, named middleware lookup, and logging.
  ///
  /// Pass [prefix] to mount the controller under an extra
  /// path segment (e.g. an `/api/v1` versioning prefix).
  void attachToApp(
    GisilaApp app,
    Router router, {
    String prefix = '',
  }) {
    {
      final basePath = '$prefix/users/ping';
      Future<Response> __inner(Request request) async {
        try {
          final __guardResult = await guardRequest(
            request,
            requireAuth: false,
            permissions: const <String>{},
            anyPermission: const <String>{},
            roles: const <String>{},
          );
          if (__guardResult is Response) return __guardResult;

          final result = await this.ping();
          return jsonResponse(result, statusCode: 200);
        } on TypeError catch (e) {
          throw BadRequestException('Invalid request payload ($e)');
        } on FormatException catch (e) {
          throw BadRequestException('Invalid request format: ${e.message}');
        }
      }

      router.get(basePath, __inner);
    }
    {
      final basePath = '$prefix/users/';
      Future<Response> __inner(Request request) async {
        try {
          final __guardResult = await guardRequest(
            request,
            requireAuth: true,
            permissions: const <String>{'users:read'},
            anyPermission: const <String>{},
            roles: const <String>{},
          );
          if (__guardResult is Response) return __guardResult;

          final limit = coerce<int?>(
              request.url.queryParameters['limit'], 'limit',
              required: false);
          final offset = coerce<int?>(
              request.url.queryParameters['offset'], 'offset',
              required: false);
          final result = await this.listUsers(limit: limit, offset: offset);
          return jsonResponse(result, statusCode: 200);
        } on TypeError catch (e) {
          throw BadRequestException('Invalid request payload ($e)');
        } on FormatException catch (e) {
          throw BadRequestException('Invalid request format: ${e.message}');
        }
      }

      router.get(basePath, __inner);
    }
    {
      final basePath = '$prefix/users/me';
      Future<Response> __inner(Request request) async {
        try {
          final __guardResult = await guardRequest(
            request,
            requireAuth: true,
            permissions: const <String>{},
            anyPermission: const <String>{},
            roles: const <String>{},
          );
          if (__guardResult is Response) return __guardResult;
          final ctx = __guardResult as RequestContext;
          final result = await this.me(ctx);
          return jsonResponse(result, statusCode: 200);
        } on TypeError catch (e) {
          throw BadRequestException('Invalid request payload ($e)');
        } on FormatException catch (e) {
          throw BadRequestException('Invalid request format: ${e.message}');
        }
      }

      router.get(basePath, __inner);
    }
    {
      final basePath = '$prefix/users/<id>';
      Future<Response> __inner(Request request) async {
        try {
          final __guardResult = await guardRequest(
            request,
            requireAuth: true,
            permissions: const <String>{'users:read'},
            anyPermission: const <String>{},
            roles: const <String>{},
          );
          if (__guardResult is Response) return __guardResult;

          final id = coerce<String>(request.params['id'], 'id', required: true);
          final result = await this.getUser(id);
          return jsonResponse(result, statusCode: 200);
        } on TypeError catch (e) {
          throw BadRequestException('Invalid request payload ($e)');
        } on FormatException catch (e) {
          throw BadRequestException('Invalid request format: ${e.message}');
        }
      }

      router.get(basePath, __inner);
    }
    {
      final basePath = '$prefix/users/';
      Future<Response> __inner(Request request) async {
        try {
          final __guardResult = await guardRequest(
            request,
            requireAuth: true,
            permissions: const <String>{'users:write'},
            anyPermission: const <String>{},
            roles: const <String>{},
          );
          if (__guardResult is Response) return __guardResult;

          final __raw_body = await readBody(request, required: true);
          final body =
              CreateUser.fromJson((__raw_body as Map).cast<String, dynamic>());
          final result = await this.createUser(body);
          return jsonResponse(result, statusCode: 201);
        } on TypeError catch (e) {
          throw BadRequestException('Invalid request payload ($e)');
        } on FormatException catch (e) {
          throw BadRequestException('Invalid request format: ${e.message}');
        }
      }

      router.post(basePath, __inner);
    }
    {
      final basePath = '$prefix/users/login';
      Future<Response> __inner(Request request) async {
        try {
          final __guardResult = await guardRequest(
            request,
            requireAuth: false,
            permissions: const <String>{},
            anyPermission: const <String>{},
            roles: const <String>{},
          );
          if (__guardResult is Response) return __guardResult;

          final __raw_body = await readBody(request, required: true);
          final body = __raw_body is FormData
              ? LoginForm.fromForm((__raw_body as Map).cast<String, dynamic>())
              : LoginForm.fromJson((__raw_body as Map).cast<String, dynamic>());
          final result = await this.login(body);
          return jsonResponse(result, statusCode: 201);
        } on TypeError catch (e) {
          throw BadRequestException('Invalid request payload ($e)');
        } on FormatException catch (e) {
          throw BadRequestException('Invalid request format: ${e.message}');
        }
      }

      router.post(basePath, __inner);
    }
    {
      final basePath = '$prefix/users/<id>/avatar';
      Future<Response> __inner(Request request) async {
        try {
          final __guardResult = await guardRequest(
            request,
            requireAuth: true,
            permissions: const <String>{'users:write'},
            anyPermission: const <String>{},
            roles: const <String>{},
          );
          if (__guardResult is Response) return __guardResult;

          final id = coerce<String>(request.params['id'], 'id', required: true);
          final __form_file = await readFormBody(request, required: true);
          final file = __form_file!.files['file'] ??
              (throw BadRequestException(
                  'Missing file "file" in multipart body.'));
          final result = await this.uploadAvatar(id, file);
          return jsonResponse(result, statusCode: 201);
        } on TypeError catch (e) {
          throw BadRequestException('Invalid request payload ($e)');
        } on FormatException catch (e) {
          throw BadRequestException('Invalid request format: ${e.message}');
        }
      }

      router.post(basePath, __inner);
    }
    {
      final basePath = '$prefix/users/<id>';
      Future<Response> __inner(Request request) async {
        try {
          final __guardResult = await guardRequest(
            request,
            requireAuth: true,
            permissions: const <String>{},
            anyPermission: const <String>{'admin', 'users:write'},
            roles: const <String>{},
          );
          if (__guardResult is Response) return __guardResult;

          final id = coerce<String>(request.params['id'], 'id', required: true);
          await this.deleteUser(id);
          return emptyResponse(statusCode: 204);
        } on TypeError catch (e) {
          throw BadRequestException('Invalid request payload ($e)');
        } on FormatException catch (e) {
          throw BadRequestException('Invalid request format: ${e.message}');
        }
      }

      router.delete(basePath, __inner);
    }
    {
      final basePath = '$prefix/users/admin/audit';
      Future<Response> __inner(Request request) async {
        try {
          final __guardResult = await guardRequest(
            request,
            requireAuth: true,
            permissions: const <String>{},
            anyPermission: const <String>{},
            roles: const <String>{'admin'},
          );
          if (__guardResult is Response) return __guardResult;

          final result = await this.audit();
          return jsonResponse(result, statusCode: 200);
        } on TypeError catch (e) {
          throw BadRequestException('Invalid request payload ($e)');
        } on FormatException catch (e) {
          throw BadRequestException('Invalid request format: ${e.message}');
        }
      }

      router.get(basePath, __inner);
    }
  }
}
