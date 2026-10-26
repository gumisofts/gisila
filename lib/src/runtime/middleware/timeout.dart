/// Request timeout middleware.
library gisila.runtime.middleware.timeout;

import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../context.dart';

/// Answers `504` when the inner handler takes longer than [timeout].
///
/// Dart futures can't be aborted, so the handler keeps running. The
/// middleware cancels the request's [RequestContext.cancellation] and
/// hands the still-running work to [RequestContext.addAbandonedWork],
/// so the database session middleware keeps the session open until the
/// handler is done and then rolls it back.
Middleware timeoutMiddleware(Duration timeout) {
  return (Handler inner) {
    return (Request request) {
      final work = Future.sync(() => inner(request));
      return work.timeout(timeout, onTimeout: () {
        final ctx = RequestContext.maybeOf(request);
        if (ctx != null) {
          ctx.cancellation.cancel();
          ctx.addAbandonedWork(work);
        } else {
          work.ignore();
        }
        return Response(
          504,
          body: jsonEncode(<String, Object?>{
            'error': <String, Object?>{
              'status': 504,
              'code': 'gateway_timeout',
              'message': 'Request exceeded ${timeout.inMilliseconds}ms timeout',
            },
          }),
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      });
    };
  };
}
