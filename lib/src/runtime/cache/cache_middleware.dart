/// Cache middleware — attaches the configured [CacheProvider] to every
/// [RequestContext] so controller methods can reach it via `ctx.cache`.
library gisila.runtime.cache.cache_middleware;

import 'package:shelf/shelf.dart';

import '../context.dart';
import 'cache_provider.dart';

/// `RequestContext.extra` key under which the [CacheProvider] is stashed.
const String kCacheKey = 'gisila.cache';

/// Attaches [provider] to every [RequestContext] that passes through
/// the pipeline.
///
/// Installed automatically by `GisilaApp.buildHandler` when
/// `AppConfig.cache` is set; rarely composed by hand.
///
/// After this middleware runs, controller methods can access the
/// cache through `ctx.cache`.
Middleware cacheMiddleware(CacheProvider provider) {
  return (Handler inner) {
    return (Request request) async {
      var ctx = RequestContext.maybeOf(request);
      ctx ??= RequestContext(requestId: 'cache-anon', request: request);
      ctx.extra[kCacheKey] = provider;

      final req = request.change(context: <String, Object?>{
        ...request.context,
        kContextKey: ctx,
      });

      return inner(req);
    };
  };
}
