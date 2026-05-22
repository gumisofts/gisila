/// Simple token-bucket rate limiter middleware.
///
/// In-process only. For a real deployment swap in a Redis-backed
/// implementation by writing your own middleware - the framework has
/// no opinion on transport.
library gisila.runtime.middleware.rate_limit;

import 'package:shelf/shelf.dart';

/// Configuration for [rateLimitMiddleware].
class RateLimitConfig {
  const RateLimitConfig({
    this.requestsPerMinute = 120,
    this.burstSize,
    this.keyExtractor,
  });

  /// Allowed steady-state rate.
  final int requestsPerMinute;

  /// Maximum burst size; defaults to [requestsPerMinute].
  final int? burstSize;

  /// Returns the bucket key for a request. Defaults to the remote
  /// address from `X-Forwarded-For` / `request.context['shelf.io.connection_info']`.
  final String Function(Request request)? keyExtractor;
}

Middleware rateLimitMiddleware([
  RateLimitConfig config = const RateLimitConfig(),
]) {
  final maxTokens = config.burstSize ?? config.requestsPerMinute;
  final refillPerSecond = config.requestsPerMinute / 60.0;
  final keyOf = config.keyExtractor ?? _defaultKey;
  final buckets = <String, _Bucket>{};

  return (Handler inner) {
    return (Request request) async {
      final key = keyOf(request);
      final bucket = buckets.putIfAbsent(
        key,
        () => _Bucket(tokens: maxTokens.toDouble(), lastRefill: DateTime.now()),
      );
      final now = DateTime.now();
      final elapsed = now.difference(bucket.lastRefill).inMilliseconds / 1000.0;
      bucket.tokens = (bucket.tokens + elapsed * refillPerSecond)
          .clamp(0, maxTokens.toDouble());
      bucket.lastRefill = now;

      if (bucket.tokens < 1) {
        return Response(
          429,
          body: '{"error":{"status":429,"code":"too_many_requests",'
              '"message":"Rate limit exceeded"}}',
          headers: const {
            'content-type': 'application/json; charset=utf-8',
            'retry-after': '60',
          },
        );
      }
      bucket.tokens -= 1;
      return inner(request);
    };
  };
}

String _defaultKey(Request request) {
  final fwd = request.headers['x-forwarded-for'];
  if (fwd != null && fwd.isNotEmpty) return fwd.split(',').first.trim();
  // Fall back to the per-server connection info, if Shelf exposes it.
  final info = request.context['shelf.io.connection_info'];
  if (info != null) return info.toString();
  return 'global';
}

class _Bucket {
  _Bucket({required this.tokens, required this.lastRefill});
  double tokens;
  DateTime lastRefill;
}
