/// CORS middleware.
library gisila.runtime.middleware.cors;

import 'package:shelf/shelf.dart';

/// Configuration for the [corsMiddleware].
class CorsConfig {
  const CorsConfig({
    this.allowedOrigins = const <String>{'*'},
    this.allowedMethods = const <String>{
      'GET',
      'POST',
      'PUT',
      'PATCH',
      'DELETE',
      'OPTIONS'
    },
    this.allowedHeaders = const <String>{
      'Content-Type',
      'Authorization',
      'X-Request-Id'
    },
    this.exposedHeaders = const <String>{},
    this.allowCredentials = false,
    this.maxAge = const Duration(hours: 1),
  });

  final Set<String> allowedOrigins;
  final Set<String> allowedMethods;
  final Set<String> allowedHeaders;
  final Set<String> exposedHeaders;
  final bool allowCredentials;
  final Duration maxAge;

  bool allowsOrigin(String origin) =>
      allowedOrigins.contains('*') || allowedOrigins.contains(origin);
}

/// CORS middleware honouring [config].
///
/// A pre-flight (an `OPTIONS` request carrying `Origin` and
/// `Access-Control-Request-Method`) from an allowed origin is answered here
/// with a `204` and the negotiated headers; one from any other origin gets a
/// `403`. Other `OPTIONS` requests reach the router like any request.
///
/// Throws [ArgumentError] for `'*'` with [CorsConfig.allowCredentials]:
/// credentialed requests can't use a wildcard, and echoing every origin
/// instead would let any site make authenticated calls. List the origins.
Middleware corsMiddleware([CorsConfig config = const CorsConfig()]) {
  final wildcard = config.allowedOrigins.contains('*');
  if (wildcard && config.allowCredentials) {
    throw ArgumentError(
        'CorsConfig: allowCredentials needs explicit allowedOrigins, not '
        "'*'. Any website could otherwise make credentialed requests.");
  }
  return (Handler inner) {
    return (Request request) async {
      final origin = request.headers['origin'];
      final allowed = origin != null && config.allowsOrigin(origin);
      final corsHeaders = <String, String>{};
      if (allowed) {
        corsHeaders['Access-Control-Allow-Origin'] = wildcard ? '*' : origin;
        if (config.allowCredentials) {
          corsHeaders['Access-Control-Allow-Credentials'] = 'true';
        }
        if (config.exposedHeaders.isNotEmpty) {
          corsHeaders['Access-Control-Expose-Headers'] =
              config.exposedHeaders.join(', ');
        }
      }

      final isPreflight = request.method == 'OPTIONS' &&
          origin != null &&
          request.headers['access-control-request-method'] != null;
      if (isPreflight) {
        if (!allowed) {
          return Response.forbidden('CORS origin not allowed',
              headers: const {'Vary': 'Origin'});
        }
        return Response(
          204,
          headers: <String, String>{
            ...corsHeaders,
            if (!wildcard)
              'Vary': 'Origin, Access-Control-Request-Method, '
                  'Access-Control-Request-Headers',
            'Access-Control-Allow-Methods': config.allowedMethods.join(', '),
            'Access-Control-Allow-Headers': config.allowedHeaders.join(', '),
            'Access-Control-Max-Age': config.maxAge.inSeconds.toString(),
          },
        );
      }

      final response = await inner(request);
      if (!wildcard) {
        // The answer depends on the Origin (allowed or not), so caches must
        // key on it.
        final vary = response.headers['vary'];
        corsHeaders['Vary'] = vary == null || vary.isEmpty
            ? 'Origin'
            : vary.toLowerCase().contains('origin')
                ? vary
                : '$vary, Origin';
      }
      if (corsHeaders.isEmpty) return response;
      // `change` merges, so multi-value headers (Set-Cookie) survive.
      return response.change(headers: corsHeaders);
    };
  };
}
