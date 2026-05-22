/// Application bootstrap.
library gisila.runtime.app;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'config.dart';
import 'exceptions.dart';
import 'logging/log_event.dart';
import 'middleware/cors.dart';
import 'middleware/rate_limit.dart';
import 'middleware/request_id.dart';
import 'middleware/request_logging.dart';

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

    // App-injection middleware: stash the app on every request context.
    pipeline = pipeline.addMiddleware((inner) {
      return (Request request) {
        final req = request.change(context: {
          ...request.context,
          kAppKey: this,
        });
        return inner(req);
      };
    });

    pipeline = pipeline
        .addMiddleware(requestIdMiddleware(headerName: config.requestIdHeader));

    if (config.cors != null) {
      pipeline = pipeline.addMiddleware(corsMiddleware(config.cors!));
    }
    if (config.rateLimit != null) {
      pipeline = pipeline.addMiddleware(rateLimitMiddleware(config.rateLimit!));
    }
    if (config.maxRequestBodyBytes != null) {
      pipeline = pipeline
          .addMiddleware(_bodySizeLimitMiddleware(config.maxRequestBodyBytes!));
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

    for (final mw in _userMiddleware) {
      pipeline = pipeline.addMiddleware(mw);
    }

    pipeline = pipeline.addMiddleware(_serverHeadersMiddleware());

    if (config.requestTimeout != null) {
      pipeline =
          pipeline.addMiddleware(_timeoutMiddleware(config.requestTimeout!));
    }

    return pipeline.addHandler(router.call);
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
        } catch (error, stack) {
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
        final headers = <String, String>{
          ...response.headersAll.map((k, v) => MapEntry(k, v.join(','))),
        };
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

  Middleware _timeoutMiddleware(Duration timeout) {
    return (Handler inner) {
      return (Request request) async {
        try {
          return await Future.sync(() => inner(request)).timeout(timeout);
        } on TimeoutException {
          return Response(
            504,
            body: jsonEncode(<String, Object?>{
              'error': <String, Object?>{
                'status': 504,
                'code': 'gateway_timeout',
                'message':
                    'Request exceeded ${timeout.inMilliseconds}ms timeout',
              },
            }),
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }
      };
    };
  }
}

Middleware _bodySizeLimitMiddleware(int maxBytes) {
  return (Handler inner) {
    return (Request request) async {
      final contentLength = request.contentLength;
      if (contentLength != null && contentLength > maxBytes) {
        return Response(
          413,
          body: jsonEncode(<String, Object?>{
            'error': <String, Object?>{
              'status': 413,
              'code': 'payload_too_large',
              'message': 'Request body exceeds limit of $maxBytes bytes',
            },
          }),
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return inner(request);
    };
  };
}

class _RegisteredController {
  _RegisteredController({required this.attacher, required this.prefix});
  final ControllerAttacher attacher;
  final String prefix;
}
