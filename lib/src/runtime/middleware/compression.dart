/// gzip response compression.
library gisila.runtime.middleware.compression;

import 'dart:io' show GZipCodec;

import 'package:shelf/shelf.dart';

/// Settings for [compressionMiddleware].
class CompressionConfig {
  const CompressionConfig({
    this.minBytes = 1024,
    this.level = 6,
    this.mimeTypes = defaultCompressibleTypes,
    this.shouldCompress,
  });

  /// Bodies of known length below this are sent as they are: compressing
  /// them costs more than it saves. Bodies of unknown length (streams) are
  /// always compressed.
  final int minBytes;

  /// gzip level, 1 (fastest) to 9 (smallest).
  final int level;

  /// MIME types (without parameters) that are compressed. A `type/*`
  /// entry covers the whole type.
  final Set<String> mimeTypes;

  /// Final say per response, for example to leave out pages that put a
  /// secret next to text the caller controls (see BREACH).
  final bool Function(Request request, Response response)? shouldCompress;

  static const Set<String> defaultCompressibleTypes = <String>{
    'application/json',
    'application/problem+json',
    'application/javascript',
    'application/xml',
    'application/x-www-form-urlencoded',
    'image/svg+xml',
    'text/*',
  };

  bool _compressible(String? mimeType) {
    if (mimeType == null) return false;
    final type = mimeType.toLowerCase();
    // Server-sent events must reach the client as they're written.
    if (type == 'text/event-stream') return false;
    return mimeTypes.contains(type) ||
        mimeTypes.contains('${type.split('/').first}/*');
  }
}

/// gzips responses when the client sends `Accept-Encoding: gzip`.
///
/// Skipped for `HEAD`, for statuses without a body (1xx, 204, 304), for
/// responses that already carry `Content-Encoding` (a handler can send
/// `Content-Encoding: identity` to opt out), and for MIME types outside
/// [CompressionConfig.mimeTypes]. Adds `Vary: Accept-Encoding`, and turns
/// a strong `ETag` weak since the bytes are no longer the ones it named.
Middleware compressionMiddleware(
    [CompressionConfig config = const CompressionConfig()]) {
  if (config.level < 1 || config.level > 9) {
    throw ArgumentError.value(config.level, 'level', 'must be 1 to 9');
  }
  final codec = GZipCodec(level: config.level);
  return (Handler inner) {
    return (Request request) async {
      final response = await inner(request);
      final status = response.statusCode;
      final length = response.contentLength;
      if (request.method == 'HEAD' ||
          status < 200 ||
          status == 204 ||
          status == 304 ||
          response.headers.containsKey('content-encoding') ||
          !config._compressible(response.mimeType) ||
          (length != null && length < config.minBytes)) {
        return _withVary(response, config, request);
      }
      if (!acceptsGzip(request.headers['accept-encoding'])) {
        return _withVary(response, config, request);
      }
      if (config.shouldCompress != null &&
          !config.shouldCompress!(request, response)) {
        return response;
      }

      final Object body;
      if (length != null) {
        final bytes = <int>[];
        await for (final chunk in response.read()) {
          bytes.addAll(chunk);
        }
        body = codec.encode(bytes);
      } else {
        body = codec.encoder.bind(response.read());
      }

      final headers = <String, List<String>>{
        for (final e in response.headersAll.entries)
          if (e.key != 'content-length' && e.key != 'etag') e.key: e.value,
        'content-encoding': ['gzip'],
        'vary': [_vary(response.headers['vary'])],
      };
      final etag = response.headers['etag'];
      if (etag != null) {
        headers['etag'] = [etag.startsWith('W/') ? etag : 'W/$etag'];
      }
      return Response(status,
          body: body, headers: headers, context: response.context);
    };
  };
}

/// Adds `Vary: Accept-Encoding` to responses whose encoding depends on
/// the request, so shared caches keep the gzip and plain copies apart.
Response _withVary(
    Response response, CompressionConfig config, Request request) {
  final status = response.statusCode;
  final mayVary = request.method != 'HEAD' &&
      status >= 200 &&
      status != 204 &&
      !response.headers.containsKey('content-encoding') &&
      config._compressible(response.mimeType);
  if (!mayVary) return response;
  final vary = response.headers['vary'];
  final merged = _vary(vary);
  return merged == vary ? response : response.change(headers: {'vary': merged});
}

String _vary(String? existing) {
  if (existing == null || existing.trim().isEmpty) return 'Accept-Encoding';
  final parts = existing.split(',').map((s) => s.trim().toLowerCase());
  if (parts.contains('accept-encoding') || parts.contains('*')) {
    return existing;
  }
  return '$existing, Accept-Encoding';
}

/// Whether an `Accept-Encoding` header allows gzip (`gzip`, `x-gzip` or
/// `*`, without `q=0`).
bool acceptsGzip(String? acceptEncoding) {
  if (acceptEncoding == null) return false;
  double? gzip;
  double? any;
  for (final part in acceptEncoding.split(',')) {
    final pieces = part.split(';');
    final coding = pieces.first.trim().toLowerCase();
    var q = 1.0;
    for (final p in pieces.skip(1)) {
      final kv = p.trim().toLowerCase();
      if (kv.startsWith('q=')) q = double.tryParse(kv.substring(2)) ?? 0;
    }
    if (coding == 'gzip' || coding == 'x-gzip') gzip = q;
    if (coding == '*') any = q;
  }
  return (gzip ?? any ?? 0) > 0;
}
