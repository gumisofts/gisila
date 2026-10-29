/// HTTP request metrics and the `/metrics` endpoint.
library gisila.runtime.metrics.metrics_middleware;

import 'dart:convert';
import 'dart:io' show HttpConnectionInfo;
import 'dart:isolate' show SendPort;

import 'package:shelf/shelf.dart';

import '../context.dart';
import '../exceptions.dart';
import 'metrics.dart';
import 'metrics_hub.dart';

/// `RequestContext.extra` key holding the matched route's path template
/// (`/users/<id>`), set by generated routes.
const String kRouteTemplateKey = 'gisila.route_template';

/// Settings for the metrics endpoint and request metrics
/// (`AppConfig.metrics`).
///
/// Who may read [path]: with [allow], whoever it accepts; otherwise with
/// [bearerToken], requests that send it; otherwise only direct
/// connections from loopback that carry no `X-Forwarded-For`,
/// `Forwarded` or `X-Real-IP` header, so a reverse proxy on the same host
/// doesn't publish it. Everyone else gets a 404.
class MetricsConfig {
  const MetricsConfig({
    this.path = '/metrics',
    this.bearerToken,
    this.allow,
    this.hub,
    this.buckets = defaultLatencyBuckets,
  });

  final String path;

  /// At least 16 characters.
  final String? bearerToken;
  final bool Function(Request request)? allow;

  /// A [MetricsHub.sendPort], when several isolates serve one port.
  final SendPort? hub;

  /// Buckets of `http_server_request_duration_seconds`.
  final List<double> buckets;
}

const _methods = {'GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'};

/// Records `http_server_requests_total`,
/// `http_server_request_duration_seconds` and
/// `http_server_requests_in_flight` in [registry], and serves
/// [MetricsConfig.path]. Requests to the metrics path itself aren't
/// counted.
Middleware metricsMiddleware(MetricsConfig config, MetricsRegistry registry,
    {MetricsHubMember? hub}) {
  final token = config.bearerToken;
  if (token != null && token.length < 16) {
    throw ArgumentError.value(
        '<redacted>', 'bearerToken', 'must be at least 16 characters');
  }
  final path =
      config.path.startsWith('/') ? config.path.substring(1) : config.path;
  final total = registry.counter('http_server_requests_total',
      help: 'HTTP requests answered.', labels: ['method', 'route', 'status']);
  final duration = registry.histogram('http_server_request_duration_seconds',
      help: 'Time until the response headers were ready.',
      labels: ['method', 'route'],
      buckets: config.buckets);
  final inFlight = registry.gauge('http_server_requests_in_flight',
      help: 'HTTP requests being handled.');

  return (Handler inner) {
    return (Request request) async {
      if (request.url.path == path) {
        if (!_allowed(request, config)) {
          return Response.notFound(jsonEncode(NotFound().toJson()),
              headers: {'content-type': 'application/json'});
        }
        final snap = hub == null ? registry.snapshot() : await hub.scrape();
        return Response.ok(renderSnapshot(snap), headers: {
          'content-type': 'text/plain; version=0.0.4; charset=utf-8',
          'cache-control': 'no-store',
        });
      }

      final sw = Stopwatch()..start();
      inFlight.inc();
      var status = 500;
      try {
        final response = await inner(request);
        status = response.statusCode;
        return response;
      } finally {
        inFlight.dec();
        final method =
            _methods.contains(request.method) ? request.method : 'OTHER';
        final template =
            RequestContext.maybeOf(request)?.extra[kRouteTemplateKey];
        final route = template is String
            ? template
            : (status == 404 ? 'unmatched' : 'other');
        total.inc({'method': method, 'route': route, 'status': '$status'});
        duration.observe(
            sw.elapsedMicroseconds / 1e6, {'method': method, 'route': route});
      }
    };
  };
}

bool _allowed(Request request, MetricsConfig config) {
  if (config.allow != null) return config.allow!(request);
  final token = config.bearerToken;
  if (token != null) {
    return _constantTimeEquals(
        request.headers['authorization'] ?? '', 'Bearer $token');
  }
  final h = request.headers;
  if (h.containsKey('x-forwarded-for') ||
      h.containsKey('forwarded') ||
      h.containsKey('x-real-ip')) {
    return false;
  }
  final info = request.context['shelf.io.connection_info'];
  return info is HttpConnectionInfo && info.remoteAddress.isLoopback;
}

bool _constantTimeEquals(String a, String b) {
  final x = utf8.encode(a);
  final y = utf8.encode(b);
  var diff = x.length ^ y.length;
  for (var i = 0; i < x.length && i < y.length; i++) {
    diff |= x[i] ^ y[i];
  }
  return diff == 0;
}
