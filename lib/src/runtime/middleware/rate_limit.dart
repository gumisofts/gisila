/// Simple token-bucket rate limiter middleware.
///
/// In-process only. For a real deployment swap in a Redis-backed
/// implementation by writing your own middleware - the framework has
/// no opinion on transport.
library gisila.runtime.middleware.rate_limit;

import 'dart:io';

import 'package:shelf/shelf.dart';

/// Configuration for [rateLimitMiddleware].
class RateLimitConfig {
  const RateLimitConfig({
    this.requestsPerMinute = 120,
    this.burstSize,
    this.keyExtractor,
    this.trustedProxies = const <String>{},
    this.maxBuckets = 100000,
  });

  /// Allowed steady-state rate.
  final int requestsPerMinute;

  /// Maximum burst size; defaults to [requestsPerMinute].
  final int? burstSize;

  /// Returns the bucket key for a request. Defaults to the client
  /// address from [clientAddress].
  final String Function(Request request)? keyExtractor;

  /// Proxy addresses (exact IPs or CIDR ranges such as `10.0.0.0/8`)
  /// whose `X-Forwarded-For` header is trusted. Merged with
  /// `AppConfig.trustedProxies`. With none, `X-Forwarded-For` is
  /// ignored and the socket's peer address is the key.
  final Set<String> trustedProxies;

  /// Upper bound on tracked clients. Idle buckets are swept first;
  /// beyond this the least recently used ones are dropped.
  final int maxBuckets;
}

/// Resolves the client address of [request].
///
/// Uses the socket's peer address. `X-Forwarded-For` is only honoured
/// when that peer is in [trustedProxies]; the header is then walked
/// right to left and the first address that is not itself a trusted
/// proxy wins. Returns `null` when the request did not come from a
/// socket (e.g. in-memory tests) and carries no usable header.
String? clientAddress(Request request, {Set<String> trustedProxies = const {}}) {
  final info = request.context['shelf.io.connection_info'];
  final peer = info is HttpConnectionInfo ? info.remoteAddress.address : null;
  if (trustedProxies.isEmpty) return peer;

  final matcher = _ProxyMatcher(trustedProxies);
  if (peer != null && !matcher.matches(peer)) return peer;

  final fwd = request.headers['x-forwarded-for'];
  if (fwd == null || fwd.isEmpty) return peer;
  final hops = fwd
      .split(',')
      .map((h) => h.trim())
      .where((h) => h.isNotEmpty)
      .toList();
  for (final hop in hops.reversed) {
    if (!matcher.matches(hop)) return hop;
  }
  return hops.isNotEmpty ? hops.first : peer;
}

Middleware rateLimitMiddleware([
  RateLimitConfig config = const RateLimitConfig(),
  Set<String> trustedProxies = const <String>{},
]) {
  final maxTokens = (config.burstSize ?? config.requestsPerMinute).toDouble();
  final refillPerSecond = config.requestsPerMinute / 60.0;
  final proxies = <String>{...config.trustedProxies, ...trustedProxies};
  _ProxyMatcher(proxies); // Fail fast on a malformed entry.
  final keyOf = config.keyExtractor ??
      (Request r) => clientAddress(r, trustedProxies: proxies) ?? 'unknown';
  // Insertion order doubles as LRU order: a bucket is re-inserted on
  // every hit.
  final buckets = <String, _Bucket>{};
  // A bucket idle this long has refilled completely, so dropping it
  // loses nothing.
  final idleAfter = Duration(
    milliseconds: (maxTokens / refillPerSecond * 1000).ceil(),
  );
  var lastSweep = DateTime.now();

  void sweep(DateTime now) {
    lastSweep = now;
    buckets.removeWhere((_, b) => now.difference(b.lastRefill) >= idleAfter);
    while (buckets.length > config.maxBuckets) {
      buckets.remove(buckets.keys.first);
    }
  }

  return (Handler inner) {
    return (Request request) async {
      final now = DateTime.now();
      if (buckets.length > config.maxBuckets ||
          now.difference(lastSweep) >= const Duration(minutes: 1)) {
        sweep(now);
      }

      final key = keyOf(request);
      final bucket = buckets.remove(key) ??
          _Bucket(tokens: maxTokens, lastRefill: now);
      buckets[key] = bucket;
      final elapsed = now.difference(bucket.lastRefill).inMilliseconds / 1000.0;
      bucket.tokens =
          (bucket.tokens + elapsed * refillPerSecond).clamp(0, maxTokens);
      bucket.lastRefill = now;

      if (bucket.tokens < 1) {
        final retryAfter = ((1 - bucket.tokens) / refillPerSecond).ceil();
        return Response(
          429,
          body: '{"error":{"status":429,"code":"too_many_requests",'
              '"message":"Rate limit exceeded"}}',
          headers: {
            'content-type': 'application/json; charset=utf-8',
            'retry-after': '${retryAfter < 1 ? 1 : retryAfter}',
          },
        );
      }
      bucket.tokens -= 1;
      return inner(request);
    };
  };
}

class _Bucket {
  _Bucket({required this.tokens, required this.lastRefill});
  double tokens;
  DateTime lastRefill;
}

/// Matches addresses against exact IPs and CIDR ranges.
class _ProxyMatcher {
  _ProxyMatcher(Set<String> entries) {
    for (final entry in entries) {
      final slash = entry.indexOf('/');
      final ip = InternetAddress.tryParse(
          slash < 0 ? entry.trim() : entry.substring(0, slash).trim());
      if (ip == null) {
        throw ArgumentError.value(entry, 'trustedProxies', 'not an IP or CIDR');
      }
      final bits = ip.rawAddress.length * 8;
      final prefix =
          slash < 0 ? bits : int.tryParse(entry.substring(slash + 1).trim());
      if (prefix == null || prefix < 0 || prefix > bits) {
        throw ArgumentError.value(entry, 'trustedProxies', 'bad prefix');
      }
      _ranges.add((ip.rawAddress, prefix));
    }
  }

  final List<(List<int>, int)> _ranges = [];

  bool matches(String address) {
    final ip = InternetAddress.tryParse(address);
    if (ip == null) return false;
    final raw = ip.rawAddress;
    for (final (net, prefix) in _ranges) {
      if (net.length != raw.length) continue;
      if (_samePrefix(net, raw, prefix)) return true;
    }
    return false;
  }

  static bool _samePrefix(List<int> a, List<int> b, int prefix) {
    var i = 0;
    for (; prefix >= 8; prefix -= 8, i++) {
      if (a[i] != b[i]) return false;
    }
    if (prefix == 0) return true;
    final mask = (0xff << (8 - prefix)) & 0xff;
    return (a[i] & mask) == (b[i] & mask);
  }
}
