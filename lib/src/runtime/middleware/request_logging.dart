/// Per-request structured logging middleware.
library gisila.runtime.middleware.request_logging;

import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

import '../context.dart';
import '../exceptions.dart' show PayloadTooLarge;
import '../logging/log_event.dart';
import '../logging/logger.dart';

/// Middleware that emits a single log line per request, including the
/// HTTP method, path, status code, duration and request id.
///
/// The verbosity (level + whether request/response bodies are
/// captured) is configured on the [AppConfig].
Middleware requestLoggingMiddleware({
  required Logger logger,
  bool logRequestBody = false,
  bool logResponseBody = false,
  LogLevel level = LogLevel.info,
  int bodyTruncate = 2048,
}) {
  return (Handler inner) {
    return (Request request) async {
      final ctx = RequestContext.maybeOf(request);
      final requestId = ctx?.requestId;
      final stopwatch = Stopwatch()..start();

      String? requestBody;
      var req = request;
      if (logRequestBody) {
        try {
          requestBody = await req.readAsString();
        } on PayloadTooLarge catch (e) {
          return Response(
            e.statusCode,
            body: jsonEncode(e.toJson()),
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }
        req = req.change(body: requestBody);
      }

      try {
        final response = await inner(req);
        stopwatch.stop();

        String? responseBody;
        var res = response;
        // Streams of unknown length (server-sent events, file downloads)
        // may never end: leave them unread.
        if (logResponseBody &&
            response.contentLength != null &&
            response.mimeType != 'text/event-stream') {
          responseBody = await response.readAsString();
          res = response.change(body: responseBody);
        }

        logger.log(LogEvent(
          level: level,
          message: '${request.method} ${request.requestedUri.path} '
              '-> ${response.statusCode} (${stopwatch.elapsedMilliseconds}ms)',
          timestamp: DateTime.now().toUtc(),
          requestId: requestId,
          principalId: ctx?.principal?.id,
          fields: <String, Object?>{
            'method': request.method,
            'path': request.requestedUri.path,
            'query': request.requestedUri.query,
            'status': response.statusCode,
            'duration_ms': stopwatch.elapsedMilliseconds,
            'remote': _remoteOf(request),
            if (requestBody != null)
              'requestBody': _truncate(requestBody, bodyTruncate),
            if (responseBody != null)
              'responseBody': _truncate(responseBody, bodyTruncate),
          },
        ));
        return res;
      } on HijackException {
        stopwatch.stop();
        logger.log(LogEvent(
          level: level,
          message: '${request.method} ${request.requestedUri.path} '
              '-> 101 upgraded (${stopwatch.elapsedMilliseconds}ms)',
          timestamp: DateTime.now().toUtc(),
          requestId: requestId,
          principalId: ctx?.principal?.id,
          fields: <String, Object?>{
            'method': request.method,
            'path': request.requestedUri.path,
            'status': 101,
            'duration_ms': stopwatch.elapsedMilliseconds,
          },
        ));
        rethrow;
      } catch (error, stack) {
        stopwatch.stop();
        logger.log(LogEvent(
          level: LogLevel.error,
          message: '${request.method} ${request.requestedUri.path} '
              '-> ERROR (${stopwatch.elapsedMilliseconds}ms)',
          timestamp: DateTime.now().toUtc(),
          requestId: requestId,
          principalId: ctx?.principal?.id,
          error: error,
          stackTrace: stack,
          fields: <String, Object?>{
            'method': request.method,
            'path': request.requestedUri.path,
            'duration_ms': stopwatch.elapsedMilliseconds,
          },
        ));
        rethrow;
      }
    };
  };
}

String _truncate(String value, int max) =>
    value.length <= max ? value : '${value.substring(0, max)}...';

String _remoteOf(Request request) {
  final fwd = request.headers['x-forwarded-for'];
  if (fwd != null && fwd.isNotEmpty) return fwd.split(',').first.trim();
  final info = request.context['shelf.io.connection_info'];
  if (info is HttpConnectionInfo) {
    return '${info.remoteAddress.address}:${info.remotePort}';
  }
  return '';
}
