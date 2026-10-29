/// ETags and `304 Not Modified` for unchanged responses.
library gisila.runtime.middleware.etag;

import 'package:crypto/crypto.dart' show sha256;
import 'package:shelf/shelf.dart';

/// Settings for [etagMiddleware].
class EtagConfig {
  const EtagConfig({this.maxBytes = 1024 * 1024});

  /// Bodies larger than this (or of unknown length) get no ETag: hashing
  /// them would mean holding them in memory.
  final int maxBytes;
}

/// Gives successful `GET` / `HEAD` responses an `ETag` (a hash of the
/// body) and answers `304 Not Modified` with no body when the request's
/// `If-None-Match` names it.
///
/// A handler's own `ETag` is kept and still honoured. Responses marked
/// `Cache-Control: no-store` are left alone.
Middleware etagMiddleware([EtagConfig config = const EtagConfig()]) {
  return (Handler inner) {
    return (Request request) async {
      final response = await inner(request);
      if ((request.method != 'GET' && request.method != 'HEAD') ||
          response.statusCode != 200 ||
          (response.headers['cache-control'] ?? '')
              .toLowerCase()
              .contains('no-store')) {
        return response;
      }

      var current = response;
      var etag = response.headers['etag'];
      if (etag == null) {
        final length = response.contentLength;
        if (length == null || length > config.maxBytes) return response;
        final bytes = <int>[];
        await for (final chunk in response.read()) {
          bytes.addAll(chunk);
        }
        etag = '"${sha256.convert(bytes).toString().substring(0, 32)}"';
        current = response.change(body: bytes, headers: {'etag': etag});
      }

      if (!ifNoneMatchHits(request.headers['if-none-match'], etag)) {
        return current;
      }
      const kept = {
        'etag',
        'cache-control',
        'expires',
        'vary',
        'content-location',
        'date',
        'last-modified',
      };
      return Response.notModified(headers: {
        for (final e in current.headersAll.entries)
          if (kept.contains(e.key)) e.key: e.value,
      }, context: current.context);
    };
  };
}

/// Whether an `If-None-Match` header matches [etag], using the weak
/// comparison RFC 9110 asks for (`W/"x"` matches `"x"`).
bool ifNoneMatchHits(String? ifNoneMatch, String etag) {
  if (ifNoneMatch == null) return false;
  if (ifNoneMatch.trim() == '*') return true;
  String opaque(String tag) {
    final t = tag.trim();
    return t.startsWith('W/') ? t.substring(2) : t;
  }

  final target = opaque(etag);
  return ifNoneMatch.split(',').any((t) => opaque(t) == target);
}
