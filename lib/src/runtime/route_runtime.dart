/// Runtime helper the generated controller code dispatches through.
///
/// For each annotated route the build-time generator emits:
///
/// ```dart
/// router.post(basePath, gisilaRoute(
///   app: app,
///   config: const RouteConfig(...merged...),
///   handler: (ctx) async {
///     final form = await bindForm(ctx.request, RegisterForm.new);
///     final svc  = ctx.service<AuthService>();
///     final result = await controller.register(form, svc);
///     return jsonResponse(body: result, statusCode: 201);
///   },
/// ));
/// ```
///
/// [gisilaRoute] does three things:
///
/// 1. Composes the per-route Shelf [Pipeline] from the effective
///    [RouteConfig] (rate limit, content-type filter, timeout,
///    body-size cap, custom middleware, AuthN/AuthZ).
/// 2. Materialises a [RequestContext] for the handler so the handler
///    body never needs to inspect the raw `Request` directly.
/// 3. Routes the final call through the framework's error middleware
///    (already wrapping the whole app), so exceptions surface as
///    standard JSON envelopes.
library gisila.runtime.route_runtime;

import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart';

import 'app.dart';
import 'context.dart';
import 'exceptions.dart';
import 'middleware/body_limit.dart';
import 'middleware/content_type.dart';
import 'middleware/cors.dart';
import 'middleware/rate_limit.dart';
import 'middleware/timeout.dart';
import 'route_config.dart';

/// Signature for the typed handler the generator emits.
typedef GisilaRouteHandler = FutureOr<Response> Function(RequestContext ctx);

/// Builds a Shelf [Handler] for a single route from its effective
/// [RouteConfig] + a typed [GisilaRouteHandler].
///
/// Merges `app.config.defaultRouteConfig` with [config] (the latter
/// wins on every scalar field, sets are unioned). The merged config
/// drives the per-route Shelf pipeline:
///
/// 1. Per-route CORS overrides (rare).
/// 2. Per-route rate limit.
/// 3. Per-route content-type whitelist.
/// 4. Per-route body-size cap.
/// 5. User-supplied custom middleware (in declaration order).
/// 6. Per-route timeout.
/// 7. AuthN/AuthZ guard (read straight from `config.permissions` etc.).
/// 8. The typed handler.
Handler gisilaRoute({
  required GisilaApp app,
  required RouteConfig config,
  required GisilaRouteHandler handler,
}) {
  final effective = app.config.defaultRouteConfig.merge(config);

  Handler current = (Request request) async {
    final ctx = RequestContext.maybeOf(request) ??
        RequestContext(requestId: 'unbound', request: request);
    // Refresh the context's request reference so handlers always see
    // the (potentially mutated) request that arrived at this point in
    // the pipeline.
    final boundCtx = RequestContext(
      requestId: ctx.requestId,
      request: request,
      principal: ctx.principal,
      extra: ctx.extra,
    );
    final result = await handler(boundCtx);
    return result;
  };

  // 7. AuthN/AuthZ (innermost, runs right before handler)
  if (effective.hasAuthGuards) {
    current = _authzMiddleware(app, effective)(current);
  }

  // 6. Per-route timeout
  if (effective.timeout != null) {
    current = timeoutMiddleware(effective.timeout!)(current);
  }

  // 5. User-supplied middleware (outermost user middleware runs first)
  for (final mw in effective.middleware.reversed) {
    current = mw(current);
  }

  // 4. Per-route body size cap
  if (effective.maxBodyBytes != null) {
    current = bodySizeLimitMiddleware(effective.maxBodyBytes!)(current);
  }

  // 3. Per-route content-type whitelist
  if (effective.contentTypes != null && effective.contentTypes!.isNotEmpty) {
    current = allowedContentTypesMiddleware(
      contentTypes: effective.contentTypes!,
    )(current);
  }

  // 2. Per-route rate limit
  if (effective.rateLimit != null) {
    current = rateLimitMiddleware(
      effective.rateLimit!,
      app.config.trustedProxies,
    )(current);
  }

  // 1. Per-route CORS overrides
  if (effective.cors != null) {
    current = corsMiddleware(effective.cors!)(current);
  }

  return current;
}

// ---------------------------------------------------------------------------
// Internal middleware - per-route variants of the global ones so the
// generated route definition stays self-contained.
// ---------------------------------------------------------------------------

/// Uses the [app] the route was built with rather than the one on the
/// request context, so the guards hold even when the router is
/// mounted outside `GisilaApp.buildHandler()`.
Middleware _authzMiddleware(GisilaApp app, RouteConfig cfg) {
  return (Handler inner) {
    return (Request request) async {
      final ctx = RequestContext.maybeOf(request) ??
          RequestContext(requestId: 'unbound', request: request);

      Object? authError;
      try {
        ctx.principal = await app.config.authenticator.authenticate(request);
      } catch (e) {
        authError = e;
      }

      if (authError != null) {
        return _errResp(Unauthorized(authError.toString()));
      }
      if (ctx.principal == null) {
        return _errResp(Unauthorized());
      }

      final resolver = app.config.permissionResolver;
      final p = ctx.principal!;

      for (final perm in cfg.permissions) {
        if (!await resolver.hasPermission(p, perm)) {
          return _errResp(Forbidden('Missing permission "$perm"'));
        }
      }
      if (cfg.anyPermission.isNotEmpty) {
        var ok = false;
        for (final perm in cfg.anyPermission) {
          if (await resolver.hasPermission(p, perm)) {
            ok = true;
            break;
          }
        }
        if (!ok) {
          return _errResp(
            Forbidden('Missing any of permissions ${cfg.anyPermission}'),
          );
        }
      }
      if (cfg.roles.isNotEmpty) {
        var ok = false;
        for (final role in cfg.roles) {
          if (await resolver.hasRole(p, role)) {
            ok = true;
            break;
          }
        }
        if (!ok) {
          return _errResp(Forbidden('Missing any of roles ${cfg.roles}'));
        }
      }

      // Persist the resolved principal back onto the request context so
      // downstream handlers (and ctx.principal access) see it.
      final req = request.change(context: <String, Object?>{
        ...request.context,
        kContextKey: ctx,
      });
      return inner(req);
    };
  };
}

Response _errResp(HttpException e) => Response(
      e.statusCode,
      body: jsonEncode(e.toJson()),
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
