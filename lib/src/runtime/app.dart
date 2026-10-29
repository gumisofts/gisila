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
import 'logging/logger.dart';
import 'metrics/metrics.dart';
import 'metrics/metrics_hub.dart';
import 'metrics/metrics_middleware.dart';
import 'middleware/body_limit.dart';
import 'middleware/compression.dart';
import 'middleware/cors.dart';
import 'middleware/etag.dart';
import 'middleware/rate_limit.dart';
import 'middleware/request_id.dart';
import 'middleware/request_logging.dart';
import 'middleware/security_headers.dart';
import 'middleware/timeout.dart';
import 'service.dart';
import 'static_files.dart';

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

  /// Singletons in registration order; [_Singleton.instance] is filled
  /// in by [init] for those registered with a factory.
  final Map<Type, _Singleton> _singletons = <Type, _Singleton>{};

  final List<FutureOr<void> Function()> _onStart =
      <FutureOr<void> Function()>[];
  final List<FutureOr<void> Function()> _onStop =
      <FutureOr<void> Function()>[];

  /// Set while [init] runs or once it finished, until [stop].
  Future<void>? _initialized;

  /// The app's metrics: the framework's HTTP metrics (with
  /// `AppConfig.metrics`) and any you register.
  final MetricsRegistry metrics = MetricsRegistry();

  MetricsHubMember? _hubMember;

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

  /// Registers one app-wide [instance] of [T], shared by every request
  /// (a Redis client, a mailer, an HTTP client). Read it with
  /// [singleton], `ctx.singleton<T>()` or `Service.singleton<T>()`.
  ///
  /// [dispose] runs on [stop], in reverse registration order.
  void registerSingleton<T extends Object>(T instance,
      {FutureOr<void> Function(T instance)? dispose}) {
    _addSingleton<T>(_Singleton(
        instance: instance,
        dispose: dispose == null ? null : (o) => dispose(o as T)));
  }

  /// Like [registerSingleton], but [create] runs during [init] (called by
  /// [start]), so it can be async (open a connection) and read
  /// singletons registered before it with `app.singleton<...>()`.
  void registerSingletonFactory<T extends Object>(
      FutureOr<T> Function(GisilaApp app) create,
      {FutureOr<void> Function(T instance)? dispose}) {
    _addSingleton<T>(_Singleton(
        create: create,
        dispose: dispose == null ? null : (o) => dispose(o as T)));
  }

  void _addSingleton<T>(_Singleton s) {
    if (_initialized != null) {
      throw StateError('Register singletons before start() / init().');
    }
    if (_singletons.containsKey(T)) {
      throw StateError('A singleton for $T is already registered.');
    }
    _singletons[T] = s;
  }

  /// The singleton registered as [T]. Throws [StateError] when none is
  /// registered, or when it comes from a factory that hasn't run yet.
  T singleton<T extends Object>() => _singletonResolver(T) as T;

  Object _singletonResolver(Type type) {
    final s = _singletons[type];
    if (s == null) {
      throw StateError('No singleton registered for $type. '
          'Call app.registerSingleton<$type>(...) before start().');
    }
    final instance = s.instance;
    if (instance == null) {
      throw StateError('The $type singleton is created by init() / start(), '
          'which has not run yet.');
    }
    return instance;
  }

  /// Runs [hook] during [init] (called by [start]), after the singleton
  /// factories, before the server accepts connections. Hooks run in
  /// registration order; one that throws aborts the start.
  void onStart(FutureOr<void> Function() hook) => _onStart.add(hook);

  /// Runs [hook] during [stop], after the server closed and before the
  /// singletons are disposed. Hooks run in reverse registration order;
  /// one that throws is logged and the rest still run.
  void onStop(FutureOr<void> Function() hook) => _onStop.add(hook);

  /// Connects the cache, creates factory singletons and runs [onStart]
  /// hooks. [start] calls it; call it yourself when serving through
  /// [buildHandler] (tests, a custom server). Runs once; later calls wait
  /// for the first. When a step fails, what was already set up is torn
  /// down again and the error is rethrown.
  Future<void> init() => _initialized ??= _init();

  Future<void> _init() async {
    try {
      await config.cache?.connect();
      for (final entry in _singletons.entries) {
        final s = entry.value;
        if (s.create != null) s.instance = await s.create!(this);
      }
      for (final hook in _onStart) {
        await hook();
      }
    } catch (_) {
      await _shutdown(runStopHooks: false);
      _initialized = null;
      rethrow;
    }
  }

  /// Disposes singletons (reverse order), then the cache and database.
  Future<void> _shutdown({required bool runStopHooks}) async {
    _hubMember?.close();
    _hubMember = null;
    Future<void> guarded(String what, FutureOr<void> Function() f) async {
      try {
        await f();
      } catch (e, st) {
        config.logger.error('gisila: $what failed during shutdown',
            error: e, stackTrace: st);
      }
    }

    if (runStopHooks) {
      for (final hook in _onStop.reversed) {
        await guarded('onStop hook', hook);
      }
    }
    for (final entry in _singletons.entries.toList().reversed) {
      final s = entry.value;
      final instance = s.instance;
      if (instance == null) continue;
      if (s.dispose != null) {
        await guarded('disposing ${entry.key}', () => s.dispose!(instance));
      }
      if (s.create != null) s.instance = null;
    }
    await guarded('cache disconnect', () async => config.cache?.disconnect());
    await guarded(
        'database dispose', () async => config.database?.dispose());
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

  /// Serves the files under [directory] at [prefix] (`'/'` for a whole
  /// frontend, `'/assets'`, ...). Controllers registered anywhere win over
  /// it, and paths it has no file for fall through to the next mount and
  /// then the JSON 404. See [StaticFilesConfig] for caching and the
  /// single-page-app fallback.
  void serveStatic(String prefix, String directory,
      {StaticFilesConfig config = const StaticFilesConfig()}) {
    if (!prefix.startsWith('/')) {
      throw ArgumentError.value(prefix, 'prefix', 'must start with "/"');
    }
    _staticMounts.add((prefix, staticFilesHandler(directory, config)));
  }

  final List<(String, Handler)> _staticMounts = <(String, Handler)>[];

  /// Builds the full Shelf handler: framework middleware + user
  /// middleware + router.
  Handler buildHandler() {
    final router = Router(notFoundHandler: _notFound);
    for (final c in _controllers) {
      c.attacher(this, router, prefix: c.prefix);
    }
    // After the controllers, so their routes are matched first.
    for (final (prefix, handler) in _staticMounts) {
      router.mount(prefix, handler);
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
          ctx.extra[kSingletonResolverKey] = _singletonResolver;
          extras[kContextKey] = ctx;
        }
        final req = request.change(context: extras);
        return inner(req);
      };
    });

    // Outside everything that can answer early (health, CORS, rate
    // limits, errors), so those responses carry the headers too.
    if (config.securityHeaders != null) {
      pipeline = pipeline
          .addMiddleware(securityHeadersMiddleware(config.securityHeaders!));
    }

    pipeline = pipeline
        .addMiddleware(requestIdMiddleware(headerName: config.requestIdHeader));

    if (config.healthCheckPath != null) {
      pipeline = pipeline.addMiddleware(_healthMiddleware(
          config.healthCheckPath!, config.healthCheck, config.logger));
    }

    final metricsConfig = config.metrics;
    if (metricsConfig != null) {
      final hub = metricsConfig.hub;
      if (hub != null) _hubMember ??= MetricsHubMember(hub, metrics);
      pipeline = pipeline.addMiddleware(
          metricsMiddleware(metricsConfig, metrics, hub: _hubMember));
    }

    // Make sure the service resolver lands on the context that
    // requestIdMiddleware (or a downstream middleware) materialised.
    pipeline = pipeline.addMiddleware((inner) {
      return (Request request) {
        final ctx = RequestContext.maybeOf(request);
        if (ctx != null) {
          ctx.extra[kServiceResolverKey] = _serviceResolver;
          ctx.extra[kSingletonResolverKey] = _singletonResolver;
        }
        return inner(request);
      };
    });

    // Compression outside the ETags, so the hash names the plain body
    // and a gzipped copy carries the same (weakened) tag.
    if (config.compression != null) {
      pipeline =
          pipeline.addMiddleware(compressionMiddleware(config.compression!));
    }
    if (config.etags != null) {
      pipeline = pipeline.addMiddleware(etagMiddleware(config.etags!));
    }

    if (config.cache != null) {
      pipeline = pipeline.addMiddleware(cacheMiddleware(config.cache!));
    }

    if (config.cors != null) {
      pipeline = pipeline.addMiddleware(corsMiddleware(config.cors!));
    }
    if (config.rateLimit != null) {
      pipeline = pipeline.addMiddleware(rateLimitMiddleware(config.rateLimit!,
          config.trustedProxies, config.rateLimitStore, 'app'));
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
  ///
  /// With [stopOnSignals], SIGINT and SIGTERM (as sent by Ctrl-C, systemd
  /// or Docker) call [stop] with [drainTimeout] and then end the process.
  ///
  /// With [shared], several isolates can each start an app on the same
  /// port and the connections are spread between them.
  Future<HttpServer> start({
    String host = '0.0.0.0',
    int port = 8080,
    SecurityContext? securityContext,
    bool shared = false,
    bool stopOnSignals = false,
    Duration drainTimeout = const Duration(seconds: 30),
  }) async {
    await init();
    final h = buildHandler();
    _server = await shelf_io.serve(
      h,
      host,
      port,
      securityContext: securityContext,
      shared: shared,
    );
    if (stopOnSignals) {
      Future<void> onSignal(ProcessSignal signal) async {
        config.logger.info('gisila: $signal received, shutting down');
        await stop(drainTimeout: drainTimeout);
        exit(0);
      }

      _signalSubs = [
        ProcessSignal.sigint.watch().listen(onSignal),
        if (!Platform.isWindows) ProcessSignal.sigterm.watch().listen(onSignal),
      ];
    }
    config.logger.info(
      'gisila listening on http://$host:$port',
      fields: <String, Object?>{
        'controllers': _controllers.length,
        'middleware': _userMiddleware.length,
      },
    );
    return _server!;
  }

  /// Stops accepting connections and waits up to [drainTimeout] for
  /// in-flight requests before closing the rest; [force] closes at once.
  /// Then runs the [onStop] hooks, disposes the singletons and releases
  /// the cache and the database provider. Also tears down an app that was
  /// only [init]ed.
  Future<void> stop({
    bool force = false,
    Duration drainTimeout = const Duration(seconds: 30),
  }) async {
    final server = _server;
    final initialized = _initialized;
    if (server == null && initialized == null) return;
    _server = null;
    _initialized = null;
    if (server == null) {
      await initialized!.catchError((_) {});
      await _shutdown(runStopHooks: true);
      return;
    }
    for (final sub in _signalSubs) {
      await sub.cancel();
    }
    _signalSubs = const [];
    if (force) {
      await server.close(force: true);
    } else {
      // A graceful close also waits for idle keep-alive connections, which
      // may never end on their own: give in-flight requests the timeout,
      // then close whatever is left.
      try {
        await server.close().timeout(drainTimeout);
      } on TimeoutException {
        config.logger.warning('gisila: connections still open after '
            '${drainTimeout.inMilliseconds} ms; closing them');
        await server.close(force: true);
      }
    }
    await _shutdown(runStopHooks: true);
  }

  List<StreamSubscription<ProcessSignal>> _signalSubs = const [];

  /// Answers [path] without touching auth, routing or the database.
  static Middleware _healthMiddleware(
      String path, Future<bool> Function()? check, Logger logger) {
    final normalized = path.startsWith('/') ? path.substring(1) : path;
    return (Handler inner) => (Request request) async {
          if (request.method != 'GET' || request.url.path != normalized) {
            return inner(request);
          }
          var healthy = true;
          if (check != null) {
            try {
              healthy = await check();
            } catch (e, st) {
              logger.warning('health check failed: $e', stackTrace: st);
              healthy = false;
            }
          }
          return Response(
            healthy ? 200 : 503,
            body: healthy ? '{"status":"ok"}' : '{"status":"unavailable"}',
            headers: const {
              'content-type': 'application/json; charset=utf-8',
              'cache-control': 'no-store',
            },
          );
        };
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

  /// Unmatched routes answer in the same JSON envelope as other errors.
  static Response _notFound(Request request) => Response.notFound(
        jsonEncode(<String, Object?>{
          'error': <String, Object?>{
            'status': 404,
            'code': 'not_found',
            'message': 'No route for ${request.method} /${request.url.path}',
          },
        }),
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );

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

class _Singleton {
  _Singleton({this.instance, this.create, this.dispose});

  Object? instance;
  final FutureOr<Object> Function(GisilaApp app)? create;
  final FutureOr<void> Function(Object instance)? dispose;
}

class _RegisteredController {
  _RegisteredController({required this.attacher, required this.prefix});
  final ControllerAttacher attacher;
  final String prefix;
}
