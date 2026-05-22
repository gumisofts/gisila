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

/// CORS middleware honouring [config]. Pre-flight `OPTIONS` requests
/// are short-circuited with a `204` carrying the negotiated headers.
Middleware corsMiddleware([CorsConfig config = const CorsConfig()]) {
  return (Handler inner) {
    return (Request request) async {
      final origin = request.headers['origin'];
      final corsHeaders = <String, String>{};
      if (origin != null && config.allowsOrigin(origin)) {
        corsHeaders['Access-Control-Allow-Origin'] =
            config.allowedOrigins.contains('*') && !config.allowCredentials
                ? '*'
                : origin;
        if (config.allowCredentials) {
          corsHeaders['Access-Control-Allow-Credentials'] = 'true';
        }
        if (config.exposedHeaders.isNotEmpty) {
          corsHeaders['Access-Control-Expose-Headers'] =
              config.exposedHeaders.join(', ');
        }
      }

      if (request.method == 'OPTIONS') {
        return Response(
          204,
          headers: <String, String>{
            ...corsHeaders,
            'Access-Control-Allow-Methods': config.allowedMethods.join(', '),
            'Access-Control-Allow-Headers': config.allowedHeaders.join(', '),
            'Access-Control-Max-Age': config.maxAge.inSeconds.toString(),
          },
        );
      }

      final response = await inner(request);
      return response.change(headers: <String, String>{
        ...response.headersAll.map((k, v) => MapEntry(k, v.join(','))),
        ...corsHeaders,
      });
    };
  };
}
