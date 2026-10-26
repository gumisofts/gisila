/// Application bootstrap.
library gisila.runtime.app;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'cache/cache_middleware.dart';
import 'config.dart';
import 'context.dart';
import 'db/db_session_middleware.dart';
import 'exceptions.dart';
import 'forms/form.dart' show FormValidationException;
import 'logging/log_event.dart';
import 'middleware/body_limit.dart';
import 'middleware/cors.dart';
import 'middleware/rate_limit.dart';
import 'middleware/request_id.dart';
import 'middleware/request_logging.dart';
import 'middleware/timeout.dart';
import 'service.dart';

/// Signature each generated controller exposes via the
/// `attachToApp(GisilaApp app, Router router, {String prefix})`
/// extension method.
typedef ControllerAttacher = void Function(
  GisilaApp app,
  Router router, {
  String prefix,
});

/// Shelf request context key holding the active [GisilaApp].
const String kAppKey = 'gisila.app';

/// The main framework entry point.
///
/// Build it once at program start, register controllers and
/// (optionally) custom middleware, then call [start] / [handler].
class GisilaApp {
  GisilaApp({AppConfig? config}) : config = config ?? AppConfig();

  final AppConfig config;

  /// User-supplied global middleware, applied in the order they were
  /// registered. The framework's own middleware (request id, logging,
  /// CORS, rate-limit, error handler) is layered on top automatically.
  final List<Middleware> _userMiddleware = <Middleware>[];

  /// Named middleware referenced via the `@UseMiddleware('name')`
  /// annotation. Populated by [registerNamedMiddleware].
  final Map<String, Middleware> _namedMiddleware = <String, Middleware>{};

  /// Service factories registered via [registerService]. The framework
  /// instantiates a fresh [Service] per request, attaches the
  /// [RequestContext], and caches it for the rest of that request.
  final Map<Type, Service Function()> _serviceFactories =
      <Type, Service Function()>{};

  /// Functions registered via [registerController]. Defer attaching
  /// until [handler] is built so callers can mix and match controllers
  /// in any order.
  final List<_RegisteredController> _controllers = <_RegisteredController>[];

  HttpServer? _server;

  /// Adds middleware to the global pipeline. Middleware added earlier
  /// runs *outermost* (i.e. it sees the request first and the response
  /// last).
  void use(Middleware middleware) => _userMiddleware.add(middleware);

  /// Registers a middleware that controller annotations can refer to
  /// by [name] via `@UseMiddleware('name')`.
  void registerNamedMiddleware(String name, Middleware middleware) {
    _namedMiddleware[name] = middleware;
  }

  /// Looks up a named middleware. Throws [StateError] when [name] is
  /// unknown so misconfigured annotations fail fast at startup.
  Middleware namedMiddleware(String name) {
    final mw = _namedMiddleware[name];
    if (mw == null) {
      throw StateError(
          'No middleware registered for "@UseMiddleware(\'$name\')". '
          'Call GisilaApp.registerNamedMiddleware before start().');
    }
    return mw;
  }

  /// Registers a per-request [Service] factory.
  ///
  /// `app.registerService<AuthService>(AuthService.new);`
  ///
  /// The factory is invoked once per request that needs the service;
  /// the framework calls [Service.attach] to wire the
  /// [RequestContext] before the service is handed to a controller.
  void registerService<S extends Service>(ServiceFactory<S> factory) {
    _serviceFactories[S] = factory;
  }

  /// Returns the registered factory for service type [type], or
  /// `null` if none. Used by the generated controller code.
  Service Function()? serviceFactory(Type type) => _serviceFactories[type];

  /// Registers a controller. Pass the [attacher] manually if you
  /// prefer to keep your controllers opaque; the generator emits a
  /// matching extension method named `attachToApp` so you can just
  /// pass the controller itself via [withGenerated].
  void registerController({
    required ControllerAttacher attacher,
    String prefix = '',
  }) {
    _controllers.add(_RegisteredController(attacher: attacher, prefix: prefix));
  }

  /// Builds the full Shelf handler: framework middleware + user
  /// middleware + router.
  Handler buildHandler() {
    final router = Router();
    for (final c in _controllers) {
      c.attacher(this, router, prefix: c.prefix);
    }

    var pipeline = const Pipeline();

    // App-injection middleware: stash the app on every request
    // context, and install the per-request service resolver.
    pipeline = pipeline.addMiddleware((inner) {
      return (Request request) {
        final ctx = RequestContext.maybeOf(request);
        final extras = <String, Object?>{
          ...request.context,
          kAppKey: this,
        };
        if (ctx != null) {
          ctx.extra[kServiceResolverKey] = _serviceResolver;
          extras[kContextKey] = ctx;
        }
        final req = request.change(context: extras);
        return inner(req);
      };
    });

    pipeline = pipeline
        .addMiddleware(requestIdMiddleware(headerName: config.requestIdHeader));

    // Make sure the service resolver lands on the context that
    // requestIdMiddleware (or a downstream middleware) materialised.
    pipeline = pipeline.addMiddleware((inner) {
      return (Request request) {
        final ctx = RequestContext.maybeOf(request);
        if (ctx != null) {
          ctx.extra[kServiceResolverKey] = _serviceResolver;
        }
        return inner(request);
      };
    });

    if (config.cache != null) {
      pipeline = pipeline.addMiddleware(cacheMiddleware(config.cache!));
    }

    if (config.cors != null) {
      pipeline = pipeline.addMiddleware(corsMiddleware(config.cors!));
    }
    if (config.rateLimit != null) {
      pipeline = pipeline.addMiddleware(
          rateLimitMiddleware(config.rateLimit!, config.trustedProxies));
    }
    if (config.maxRequestBodyBytes != null) {
      pipeline = pipeline
          .addMiddleware(bodySizeLimitMiddleware(config.maxRequestBodyBytes!));
    }
    if (config.logRequests) {
      pipeline = pipeline.addMiddleware(requestLoggingMiddleware(
        logger: config.logger,
        logRequestBody: config.logRequestBody,
        logResponseBody: config.logResponseBody,
        level: LogLevel.info,
      ));
    }

    pipeline = pipeline.addMiddleware(_errorMappingMiddleware());

    // Inside CORS, rate limiting, the body cap and the error mapper:
    // pre-flights and rejected requests never take a connection, and a
    // failing `provider.open` renders a normal JSON error.
    if (config.database != null) {
      pipeline = pipeline.addMiddleware(dbSessionMiddleware(config.database!));
    }

    for (final mw in _userMiddleware) {
      pipeline = pipeline.addMiddleware(mw);
    }

    pipeline = pipeline.addMiddleware(_serverHeadersMiddleware());

    if (config.requestTimeout != null) {
      pipeline =
          pipeline.addMiddleware(timeoutMiddleware(config.requestTimeout!));
    }

    return pipeline.addHandler(router.call);
  }

  /// Per-request service cache + resolver. Closes over `this` so the
  /// service factory map is reachable from inside a handler that only
  /// has a [RequestContext].
  Object _serviceResolver(RequestContext ctx, Type type) {
    final cacheKey = '_gisila.svc:$type';
    final cached = ctx.extra[cacheKey];
    if (cached != null) return cached;

    final factory = _serviceFactories[type];
    if (factory == null) {
      throw StateError(
        'No service factory registered for $type. '
        'Call app.registerService<$type>(factory) before start().',
      );
    }

    final instance = factory();
    instance.attach(ctx);
    ctx.extra[cacheKey] = instance;
    return instance;
  }

  /// Backwards-friendly alias of [buildHandler] for embedders that
  /// just want a Shelf [Handler].
  Handler get handler => buildHandler();

  /// Starts the HTTP server. Returns the live [HttpServer] so callers
  /// may close it themselves; [stop] is a convenience shortcut.
  Future<HttpServer> start({
    String host = '0.0.0.0',
    int port = 8080,
    SecurityContext? securityContext,
  }) async {
    await config.cache?.connect();
    final h = buildHandler();
    _server = await shelf_io.serve(
      h,
      host,
      port,
      securityContext: securityContext,
    );
    config.logger.info(
      'gisila listening on http://$host:$port',
      fields: <String, Object?>{
        'controllers': _controllers.length,
        'middleware': _userMiddleware.length,
      },
    );
    return _server!;
  }

  Future<void> stop({bool force = false}) async {
    final server = _server;
    if (server == null) return;
    await server.close(force: force);
    _server = null;
    await config.cache?.disconnect();
  }

  /// Resolves the [GisilaApp] previously attached to [request], if
  /// any. Returns `null` outside a managed pipeline.
  static GisilaApp? maybeOf(Request request) {
    final app = request.context[kAppKey];
    return app is GisilaApp ? app : null;
  }

  // ---------------------------------------------------------------------------
  // Internal middleware
  // ---------------------------------------------------------------------------

  Middleware _errorMappingMiddleware() {
    return (Handler inner) {
      return (Request request) async {
        try {
          return await inner(request);
        } on HttpException catch (e) {
          return Response(
            e.statusCode,
            body: jsonEncode(e.toJson()),
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        } on FormValidationException catch (e) {
          return Response(
            400,
            body: jsonEncode(<String, Object?>{
              'error': <String, Object?>{
                'status': 400,
                'code': 'validation_failed',
                'message': e.message,
                'details': e.errors,
              },
            }),
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        } catch (error, stack) {
          final dbMapped = config.dbErrorMapper?.map(error, stack);
          if (dbMapped != null) {
            return Response(
              dbMapped.statusCode,
              body: jsonEncode(dbMapped.toJson()),
              headers: const {
                'content-type': 'application/json; charset=utf-8',
              },
            );
          }
          final custom = config.errorHandler;
          if (custom != null) return custom(error, stack);
          config.logger.error(
            'Unhandled exception in handler',
            error: error,
            stackTrace: stack,
          );
          return Response(
            500,
            body: jsonEncode(InternalServerError().toJson()),
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }
      };
    };
  }

  Middleware _serverHeadersMiddleware() {
    return (Handler inner) {
      return (Request request) async {
        final response = await inner(request);
        // Only the new keys: `change` merges them into the existing
        // headers, keeping multi-value ones such as Set-Cookie intact.
        final headers = <String, String>{};
        if (config.serverHeader.isNotEmpty) {
          headers['Server'] = config.serverHeader;
        }
        if (config.poweredByHeader) {
          headers['X-Powered-By'] = 'gisila';
        }
        return response.change(headers: headers);
      };
    };
  }
}

class _RegisteredController {
  _RegisteredController({required this.attacher, required this.prefix});
  final ControllerAttacher attacher;
  final String prefix;
}
