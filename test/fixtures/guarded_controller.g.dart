// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'guarded_controller.dart';

// **************************************************************************
// ControllerGenerator
// **************************************************************************

// **************************************************
// gisila: generated for GuardedController
// **************************************************

extension GuardedControllerGisilaWeb on GuardedController {
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
      final basePath = '$prefix/x/';
      final RouteConfig __cfg =
          RouteConfig.empty.merge(const RouteConfig(isPublic: true));
      final __route = gisilaRoute(
        app: app,
        config: __cfg,
        routeId: 'GET $basePath',
        handler: (RequestContext ctx) async {
          final result = await this.index();
          return jsonResponse(body: result, statusCode: 200);
        },
      );
      router.get(basePath, __route);
      if (basePath.length > 1) {
        router.get(basePath.substring(0, basePath.length - 1), __route);
      }
    }
    {
      final basePath = '$prefix/x/public';
      final RouteConfig __cfg =
          RouteConfig.empty.merge(const RouteConfig(isPublic: true));
      final __route = gisilaRoute(
        app: app,
        config: __cfg,
        routeId: 'GET $basePath',
        handler: (RequestContext ctx) async {
          final result = await this.open();
          return jsonResponse(body: result, statusCode: 200);
        },
      );
      router.get(basePath, __route);
    }
    {
      final basePath = '$prefix/x/me';
      final RouteConfig __cfg =
          RouteConfig.empty.merge(const RouteConfig(requireAuth: true));
      final __route = gisilaRoute(
        app: app,
        config: __cfg,
        routeId: 'GET $basePath',
        handler: (RequestContext ctx) async {
          final result = await this.me(ctx);
          return jsonResponse(body: result, statusCode: 200);
        },
      );
      router.get(basePath, __route);
    }
    {
      final basePath = '$prefix/x/notes';
      final RouteConfig __cfg = RouteConfig.empty.merge(const RouteConfig(
          requireAuth: true, permissions: const <String>{'write'}));
      final __route = gisilaRoute(
        app: app,
        config: __cfg,
        routeId: 'POST $basePath',
        handler: (RequestContext ctx) async {
          final request = ctx.request;
          final (form,) = await (() async {
            try {
              final form = await bindForm(request, NoteForm.new);
              return (form,);
            } on TypeError catch (e) {
              throw BadRequestException('Invalid request payload ($e)');
            } on FormatException catch (e) {
              throw BadRequestException('Invalid request format: ${e.message}');
            }
          })();
          final result = await this.create(form);
          return jsonResponse(body: result, statusCode: 201);
        },
      );
      router.post(basePath, __route);
    }
    {
      final basePath = '$prefix/x/admin';
      final RouteConfig __cfg = RouteConfig.empty.merge(
          const RouteConfig(requireAuth: true, roles: const <String>{'admin'}));
      final __route = gisilaRoute(
        app: app,
        config: __cfg,
        routeId: 'GET $basePath',
        handler: (RequestContext ctx) async {
          final result = await this.admin();
          return jsonResponse(body: result, statusCode: 200);
        },
      );
      router.get(basePath, __route);
    }
    {
      final basePath = '$prefix/x/items/<id>';
      final RouteConfig __cfg =
          RouteConfig.empty.merge(const RouteConfig(isPublic: true));
      final __route = gisilaRoute(
        app: app,
        config: __cfg,
        routeId: 'GET $basePath',
        handler: (RequestContext ctx) async {
          final request = ctx.request;
          final (id, page) = await (() async {
            try {
              final id =
                  coerce<int>(request.params['id'], 'id', required: true);
              final page = coerce<int?>(
                  request.url.queryParameters['page'], 'page',
                  required: false);
              return (id, page);
            } on TypeError catch (e) {
              throw BadRequestException('Invalid request payload ($e)');
            } on FormatException catch (e) {
              throw BadRequestException('Invalid request format: ${e.message}');
            }
          })();
          final result = await this.item(id, page: page);
          return jsonResponse(body: result, statusCode: 200);
        },
      );
      router.get(basePath, __route);
    }
    {
      final basePath = '$prefix/x/slow';
      final RouteConfig __cfg = RouteConfig.empty
          .merge(const RouteConfig(isPublic: true))
          .merge(
              const RouteConfig(timeout: const Duration(microseconds: 50000)));
      final __route = gisilaRoute(
        app: app,
        config: __cfg,
        routeId: 'GET $basePath',
        handler: (RequestContext ctx) async {
          final result = await this.slow();
          return jsonResponse(body: result, statusCode: 200);
        },
      );
      router.get(basePath, __route);
    }
    {
      final basePath = '$prefix/x/limited';
      final RouteConfig __cfg = RouteConfig.empty
          .merge(const RouteConfig(isPublic: true))
          .merge(const RouteConfig(
              rateLimit: const RateLimitConfig(requestsPerMinute: 2)));
      final __route = gisilaRoute(
        app: app,
        config: __cfg,
        routeId: 'GET $basePath',
        handler: (RequestContext ctx) async {
          final result = await this.limited();
          return jsonResponse(body: result, statusCode: 200);
        },
      );
      router.get(basePath, __route);
    }
    {
      final basePath = '$prefix/x/boom';
      final RouteConfig __cfg =
          RouteConfig.empty.merge(const RouteConfig(isPublic: true));
      final __route = gisilaRoute(
        app: app,
        config: __cfg,
        routeId: 'GET $basePath',
        handler: (RequestContext ctx) async {
          final result = await this.boom();
          return jsonResponse(body: result, statusCode: 200);
        },
      );
      router.get(basePath, __route);
    }
  }
}
