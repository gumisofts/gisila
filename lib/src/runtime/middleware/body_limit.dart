/// Request body size cap.
library gisila.runtime.middleware.body_limit;

import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../exceptions.dart';

/// Rejects request bodies larger than [maxBytes] with `413`.
///
/// A declared `Content-Length` over the limit is refused up front.
/// Otherwise (chunked bodies, or a client that lies about its length)
/// the body stream is metered and fails with [PayloadTooLarge] as soon
/// as the limit is crossed, so readers never buffer more than
/// [maxBytes]. The global error mapper renders that as a `413`.
Middleware bodySizeLimitMiddleware(int maxBytes) {
  return (Handler inner) {
    return (Request request) async {
      final contentLength = request.contentLength;
      if (contentLength != null && contentLength > maxBytes) {
        final e = PayloadTooLarge(
            'Request body exceeds limit of $maxBytes bytes');
        return Response(
          e.statusCode,
          body: jsonEncode(e.toJson()),
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return inner(request.change(body: limitBytes(request.read(), maxBytes)));
    };
  };
}

/// Passes [source] through, failing with [PayloadTooLarge] once more
/// than [maxBytes] have been seen.
Stream<List<int>> limitBytes(Stream<List<int>> source, int maxBytes) {
  var seen = 0;
  var failed = false;
  return source.transform(StreamTransformer.fromHandlers(
    handleData: (chunk, sink) {
      if (failed) return;
      seen += chunk.length;
      if (seen > maxBytes) {
        failed = true;
        sink.addError(
            PayloadTooLarge('Request body exceeds limit of $maxBytes bytes'));
        sink.close();
        return;
      }
      sink.add(chunk);
    },
    handleDone: (sink) {
      if (!failed) sink.close();
    },
  ));
}
