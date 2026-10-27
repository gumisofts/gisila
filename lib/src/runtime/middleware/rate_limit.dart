/// Token-bucket rate limiter middleware.
///
/// Buckets live in a [RateLimitStore]. The default keeps them in this
/// isolate's memory, so a server running several isolates (or several
/// processes) allows each of them the full rate. Set
/// `AppConfig.rateLimitStore` to a shared store (e.g. one backed by Redis)
/// to enforce one limit across all of them.
library gisila.runtime.middleware.rate_limit;

import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf.dart';

/// Where rate-limit token buckets are kept.
///
/// [take] removes one token from the bucket named [key] (created full on
/// first use), refilling it at [refillPerSecond] up to [capacity] since it
/// was last used. It returns null when a token was taken, or how long until
/// one will be available. Keys are already namespaced per limiter.
abstract class RateLimitStore {
  FutureOr<Duration?> take(
    String key, {
    required double capacity,
    required double refillPerSecond,
  });
}

/// The default [RateLimitStore]: buckets in this isolate's memory.
class InMemoryRateLimitStore implements RateLimitStore {
  InMemoryRateLimitStore({this.maxBuckets = 100000});

  /// Upper bound on tracked buckets. Idle (full) buckets are swept first;
  /// beyond this the least recently used ones are dropped.
  final int maxBuckets;

  // Insertion order doubles as LRU order: a bucket is re-inserted on
  // every hit.
  final _buckets = <String, _Bucket>{};
  var _lastSweep = DateTime.now();

  @override
  Duration? take(
    String key, {
    required double capacity,
    required double refillPerSecond,
  }) {
    final now = DateTime.now();
    if (_buckets.length > maxBuckets ||
        now.difference(_lastSweep) >= const Duration(minutes: 1)) {
      _sweep(now);
    }
    final bucket = _buckets.remove(key) ??
        _Bucket(
            tokens: capacity,
            lastRefill: now,
            capacity: capacity,
            refillPerSecond: refillPerSecond);
    _buckets[key] = bucket;
    final elapsed = now.difference(bucket.lastRefill).inMilliseconds / 1000.0;
    bucket.tokens =
        (bucket.tokens + elapsed * refillPerSecond).clamp(0, capacity);
    bucket.lastRefill = now;
    if (bucket.tokens < 1) {
      return Duration(
          milliseconds: ((1 - bucket.tokens) / refillPerSecond * 1000).ceil());
    }
    bucket.tokens -= 1;
    return null;
  }

  void _sweep(DateTime now) {
    _lastSweep = now;
    // A bucket idle long enough to refill completely loses nothing when
    // dropped.
    _buckets.removeWhere((_, b) =>
        now.difference(b.lastRefill).inMilliseconds / 1000.0 >=
        b.capacity / b.refillPerSecond);
    while (_buckets.length > maxBuckets) {
      _buckets.remove(_buckets.keys.first);
    }
  }
}

var _anonymousLimiters = 0;

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
String? clientAddress(Request request,
    {Set<String> trustedProxies = const {}}) {
  final info = request.context['shelf.io.connection_info'];
  final peer = info is HttpConnectionInfo ? info.remoteAddress.address : null;
  if (trustedProxies.isEmpty) return peer;

  final matcher = _ProxyMatcher(trustedProxies);
  if (peer != null && !matcher.matches(peer)) return peer;

  final fwd = request.headers['x-forwarded-for'];
  if (fwd == null || fwd.isEmpty) return peer;
  final hops =
      fwd.split(',').map((h) => h.trim()).where((h) => h.isNotEmpty).toList();
  for (final hop in hops.reversed) {
    if (!matcher.matches(hop)) return hop;
  }
  return hops.isNotEmpty ? hops.first : peer;
}

/// Limits requests per client (or per [RateLimitConfig.keyExtractor] key).
///
/// Buckets go to [store], defaulting to a fresh [InMemoryRateLimitStore]
/// for this middleware. With a shared store, [scope] names this limiter so
/// its buckets are kept apart from other limiters' and are the same in
/// every isolate (e.g. `GET /users`); without one, a scope unique to this
/// middleware instance is used.
Middleware rateLimitMiddleware([
  RateLimitConfig config = const RateLimitConfig(),
  Set<String> trustedProxies = const <String>{},
  RateLimitStore? store,
  String? scope,
]) {
  final capacity = (config.burstSize ?? config.requestsPerMinute).toDouble();
  final refillPerSecond = config.requestsPerMinute / 60.0;
  final proxies = <String>{...config.trustedProxies, ...trustedProxies};
  _ProxyMatcher(proxies); // Fail fast on a malformed entry.
  final keyOf = config.keyExtractor ??
      (Request r) => clientAddress(r, trustedProxies: proxies) ?? 'unknown';
  final buckets =
      store ?? InMemoryRateLimitStore(maxBuckets: config.maxBuckets);
  final prefix = scope ?? 'limiter-${_anonymousLimiters++}';

  return (Handler inner) {
    return (Request request) async {
      final wait = await buckets.take('$prefix|${keyOf(request)}',
          capacity: capacity, refillPerSecond: refillPerSecond);
      if (wait != null) {
        final retryAfter = (wait.inMilliseconds / 1000).ceil();
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
      return inner(request);
    };
  };
}

class _Bucket {
  _Bucket({
    required this.tokens,
    required this.lastRefill,
    required this.capacity,
    required this.refillPerSecond,
  });
  double tokens;
  DateTime lastRefill;
  final double capacity;
  final double refillPerSecond;
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
