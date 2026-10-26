// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'users_controller.dart';

// **************************************************************************
// ControllerGenerator
// **************************************************************************

// **************************************************
// gisila: generated for UsersController
// **************************************************

extension UsersControllerGisilaWeb on UsersController {
  /// Registers every annotated route of this controller on
  /// [router] using [app] for service resolution, named
  /// middleware lookup, authentication, permission checks,
  /// per-route configuration and error handling.
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
      final RouteConfig __cfg =
          RouteConfig.empty.merge(const RouteConfig(isPublic: true));
      router.get(
          basePath,
          gisilaRoute(
            app: app,
            config: __cfg,
            handler: (RequestContext ctx) async {
              final result = await this.ping();
              return jsonResponse(body: result, statusCode: 200);
            },
          ));
    }
    {
      final basePath = '$prefix/users/';
      final RouteConfig __cfg = RouteConfig.empty
          .merge(const RouteConfig(
              requireAuth: true, permissions: const <String>{'users:read'}))
          .merge(const RouteConfig(
              rateLimit: const RateLimitConfig(requestsPerMinute: 60)));
      router.get(
          basePath,
          gisilaRoute(
            app: app,
            config: __cfg,
            handler: (RequestContext ctx) async {
              final request = ctx.request;
              final (users, limit, offset) = await (() async {
                try {
                  final users = ctx.service<UserService>();
                  final limit = coerce<int?>(
                      request.url.queryParameters['limit'], 'limit',
                      required: false);
                  final offset = coerce<int?>(
                      request.url.queryParameters['offset'], 'offset',
                      required: false);
                  return (users, limit, offset);
                } on TypeError catch (e) {
                  throw BadRequestException('Invalid request payload ($e)');
                } on FormatException catch (e) {
                  throw BadRequestException(
                      'Invalid request format: ${e.message}');
                }
              })();
              final result =
                  await this.listUsers(users, limit: limit, offset: offset);
              return jsonResponse(body: result, statusCode: 200);
            },
          ));
    }
    {
      final basePath = '$prefix/users/';
      final RouteConfig __cfg = RouteConfig.empty
          .merge(const RouteConfig(isPublic: true))
          .merge(const RouteConfig(
              rateLimit: const RateLimitConfig(requestsPerMinute: 30)));
      router.post(
          basePath,
          gisilaRoute(
            app: app,
            config: __cfg,
            handler: (RequestContext ctx) async {
              final request = ctx.request;
              final (form, users) = await (() async {
                try {
                  final form = await bindForm(request, RegisterForm.new);
                  final users = ctx.service<UserService>();
                  return (form, users);
                } on TypeError catch (e) {
                  throw BadRequestException('Invalid request payload ($e)');
                } on FormatException catch (e) {
                  throw BadRequestException(
                      'Invalid request format: ${e.message}');
                }
              })();
              final result = await this.register(form, users);
              return jsonResponse(body: result, statusCode: 201);
            },
          ));
    }
    {
      final basePath = '$prefix/users/login';
      final RouteConfig __cfg =
          RouteConfig.empty.merge(const RouteConfig(isPublic: true));
      router.post(
          basePath,
          gisilaRoute(
            app: app,
            config: __cfg,
            handler: (RequestContext ctx) async {
              final request = ctx.request;
              final (form, users) = await (() async {
                try {
                  final form = await bindForm(request, LoginForm.new);
                  final users = ctx.service<UserService>();
                  return (form, users);
                } on TypeError catch (e) {
                  throw BadRequestException('Invalid request payload ($e)');
                } on FormatException catch (e) {
                  throw BadRequestException(
                      'Invalid request format: ${e.message}');
                }
              })();
              final result = await this.login(form, users);
              return jsonResponse(body: result, statusCode: 201);
            },
          ));
    }
    {
      final basePath = '$prefix/users/me';
      final RouteConfig __cfg =
          RouteConfig.empty.merge(const RouteConfig(requireAuth: true));
      router.get(
          basePath,
          gisilaRoute(
            app: app,
            config: __cfg,
            handler: (RequestContext ctx) async {
              final result = await this.me(ctx);
              return jsonResponse(body: result, statusCode: 200);
            },
          ));
    }
    {
      final basePath = '$prefix/users/<id>';
      final RouteConfig __cfg = RouteConfig.empty.merge(const RouteConfig(
          requireAuth: true, permissions: const <String>{'users:read'}));
      router.get(
          basePath,
          gisilaRoute(
            app: app,
            config: __cfg,
            handler: (RequestContext ctx) async {
              final request = ctx.request;
              final (id, users) = await (() async {
                try {
                  final id = coerce<String>(request.params['id'], 'id',
                      required: true);
                  final users = ctx.service<UserService>();
                  return (id, users);
                } on TypeError catch (e) {
                  throw BadRequestException('Invalid request payload ($e)');
                } on FormatException catch (e) {
                  throw BadRequestException(
                      'Invalid request format: ${e.message}');
                }
              })();
              final result = await this.getUser(id, users);
              return jsonResponse(body: result, statusCode: 200);
            },
          ));
    }
    {
      final basePath = '$prefix/users/<id>';
      final RouteConfig __cfg = RouteConfig.empty.merge(const RouteConfig(
          requireAuth: true, permissions: const <String>{'users:write'}));
      router.patch(
          basePath,
          gisilaRoute(
            app: app,
            config: __cfg,
            handler: (RequestContext ctx) async {
              final request = ctx.request;
              final (id, form, users) = await (() async {
                try {
                  final id = coerce<String>(request.params['id'], 'id',
                      required: true);
                  final form = await bindForm(request, UpdateUserForm.new);
                  final users = ctx.service<UserService>();
                  return (id, form, users);
                } on TypeError catch (e) {
                  throw BadRequestException('Invalid request payload ($e)');
                } on FormatException catch (e) {
                  throw BadRequestException(
                      'Invalid request format: ${e.message}');
                }
              })();
              final result = await this.updateUser(id, form, users);
              return jsonResponse(body: result, statusCode: 200);
            },
          ));
    }
    {
      final basePath = '$prefix/users/<id>';
      final RouteConfig __cfg = RouteConfig.empty.merge(const RouteConfig(
          requireAuth: true,
          anyPermission: const <String>{'admin', 'users:write'}));
      router.delete(
          basePath,
          gisilaRoute(
            app: app,
            config: __cfg,
            handler: (RequestContext ctx) async {
              final request = ctx.request;
              final (id, users) = await (() async {
                try {
                  final id = coerce<String>(request.params['id'], 'id',
                      required: true);
                  final users = ctx.service<UserService>();
                  return (id, users);
                } on TypeError catch (e) {
                  throw BadRequestException('Invalid request payload ($e)');
                } on FormatException catch (e) {
                  throw BadRequestException(
                      'Invalid request format: ${e.message}');
                }
              })();
              await this.deleteUser(id, users);
              return emptyResponse(statusCode: 204);
            },
          ));
    }
  }
}
