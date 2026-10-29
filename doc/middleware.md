# Middleware

`gisila` builds its request pipeline on top of standard
`shelf.Middleware`. You get a small catalogue out of the box, two
extension points - **global** and **named per-route** - and the same
APIs you'd use with hand-written Shelf.

This document walks through the pipeline order, the bundled
middleware, and the patterns for plugging your own in.

## Table of contents

- [Pipeline order](#pipeline-order)
- [The bundled middleware catalogue](#the-bundled-middleware-catalogue)
- [Global middleware](#global-middleware)
- [Named (per-route) middleware](#named-per-route-middleware)
- [Writing your own middleware](#writing-your-own-middleware)
- [Reading from / writing to `RequestContext`](#reading-from--writing-to-requestcontext)
- [Short-circuiting](#short-circuiting)
- [Recipe: structured request tracing](#recipe-structured-request-tracing)
- [Recipe: per-tenant rate limiting](#recipe-per-tenant-rate-limiting)
- [Compression and ETags](#compression-and-etags)
- [Recipe: request body validator](#recipe-request-body-validator)
- [Testing middleware](#testing-middleware)

## Pipeline order

`GisilaApp.buildHandler()` assembles the chain in this order (outer
to inner; "outer" sees the request first and the response last):

1. **App injection** - puts the `GisilaApp` on `request.context`.
2. **Security headers** *(unless `AppConfig.securityHeaders` is null)* -
   outside everything else, so early answers carry them too.
3. **Request id** - mints / echoes `X-Request-Id`.
4. **Compression** *(if `AppConfig.compression != null`)*.
5. **ETags** *(if `AppConfig.etags != null`)* - inside compression, so
   the tag names the plain body.
6. **Cache** *(if `AppConfig.cache != null`)*.
7. **CORS** *(if `AppConfig.cors != null`)* - answers pre-flights.
8. **Rate limit** *(if `AppConfig.rateLimit != null`)*.
9. **Body size limit** *(if `maxRequestBodyBytes != null`)*.
10. **Access log** *(if `logRequests`)*.
11. **Error mapper** - turns `HttpException` into JSON envelopes,
    forwards everything else through `AppConfig.errorHandler`.
12. **DB session** *(if `AppConfig.database != null`)* - inside the layers
    above, so pre-flights and rejected requests never take a connection.
13. **Your global middleware** (in registration order).
14. **Server headers** - `Server`, `X-Powered-By`.
15. **Request timeout** *(if `requestTimeout != null`)*.
16. **Router** → per-route pipeline (CORS override, rate limit, content
    types, body cap, named middleware, route timeout, auth guard) →
    handler.

The error mapper sits **above** your handlers so any exception you
`throw` from a route bubbles up and becomes a uniform JSON response.

## The bundled middleware catalogue

| Middleware                       | Enabled when                                  | Configured via                                  |
| -------------------------------- | --------------------------------------------- | ----------------------------------------------- |
| Request-id propagation           | always                                        | `AppConfig.requestIdHeader`                     |
| Security headers (HSTS, CSP, …)  | `AppConfig.securityHeaders != null` (default) | `SecurityHeadersConfig`                         |
| Structured access log            | `AppConfig.logRequests` (default)             | `AppConfig.logger`                              |
| CORS (incl. pre-flight)          | `AppConfig.cors != null`                      | `CorsConfig`                                    |
| gzip compression                 | `AppConfig.compression != null`               | `CompressionConfig`                             |
| ETag / 304 Not Modified          | `AppConfig.etags != null`                     | `EtagConfig`                                    |
| Token-bucket rate limit          | `AppConfig.rateLimit != null`                 | `RateLimitConfig`                               |
| Body size limit                  | `maxRequestBodyBytes != null`                 | `AppConfig.maxRequestBodyBytes`                 |
| Request timeout                  | `requestTimeout != null`                      | `AppConfig.requestTimeout`                      |
| Server / X-Powered-By            | `serverHeader.isNotEmpty` / `poweredByHeader` | `AppConfig.serverHeader`, `poweredByHeader`     |
| Error mapping (`HttpException`)  | always                                        | `AppConfig.errorHandler`                        |
| Allowed-content-types (opt-in)   | `app.use(allowedContentTypesMiddleware())`    | `contentTypes:`, `guardedMethods:`              |

All of them are also exported individually
(`corsMiddleware(config)`, `rateLimitMiddleware(config)`, etc.) so
you can re-use them outside `GisilaApp` if you ever need to.

### Allowed-content-types middleware

Rejects `POST` / `PUT` / `PATCH` requests whose `Content-Type`
(ignoring parameters) isn't in the whitelist with a uniform
`415 Unsupported Media Type` JSON envelope. The default whitelist is
the three content types the body parser knows how to decode:
`application/json`, `application/x-www-form-urlencoded`,
`multipart/form-data`.

```dart
app.use(allowedContentTypesMiddleware()); // default whitelist
// or restrict to JSON-only APIs:
app.use(allowedContentTypesMiddleware(
  contentTypes: {'application/json'},
));
// or also guard DELETE:
app.use(allowedContentTypesMiddleware(
  guardedMethods: {'POST', 'PUT', 'PATCH', 'DELETE'},
));
```

## Global middleware

Anything you want to run for **every** route goes through
`app.use(...)` - or you can add it to your own `Pipeline` *before*
wrapping it around the framework handler.

```dart
final app = GisilaApp(config: ...);

app.use(loggingMiddleware());
app.use(_addCorrelationHeaders());

app.registerController(attacher: UsersController().attachToApp);
```

Global middleware runs **after** the bundled framework middleware
(request id, access log, error mapper) but **before** the router.

## Named (per-route) middleware

`@UseMiddleware('name')` is the *route-level* extension point. The
name is just a key - the actual middleware closure is registered on
the app at startup:

```dart
app.registerNamedMiddleware('audit', auditMiddleware());
app.registerNamedMiddleware('idempotency', idempotencyMiddleware(redis));
```

Use it on a controller class (applies to every route in the class):

```dart
@Controller('/orders')
@UseMiddleware('audit')
class OrdersController { ... }
```

Or a single route:

```dart
@Post('/orders/{id}/refund')
@Permissions({'orders:refund'})
@UseMiddleware('audit')
@UseMiddleware('idempotency')
Future<RefundReceipt> refund(...) async => ...;
```

Multiple annotations stack in **annotation order**: `audit` wraps
`idempotency` wraps the handler.

If you reference a name that wasn't registered, the framework throws
a `StateError` on the **first** request hitting that route - errors
loudly so misconfigured wiring is impossible to ship silently.

## Writing your own middleware

Middleware is plain `shelf.Middleware`:

```dart
Middleware myMiddleware() {
  return (Handler inner) {
    return (Request request) async {
      // pre-processing
      final response = await inner(request);
      // post-processing
      return response;
    };
  };
}
```

You have the entire Shelf surface area available: read headers,
mutate the request via `request.change(...)`, replace the body,
short-circuit with a custom `Response`, etc.

A typical "do X and stash result for handlers" middleware:

```dart
Middleware idempotencyMiddleware(RedisClient redis) {
  return (Handler inner) {
    return (Request request) async {
      final key = request.headers['idempotency-key'];
      if (key == null) return inner(request);

      final cached = await redis.get('idem:$key');
      if (cached != null) {
        return Response(200,
            body: cached,
            headers: const {'content-type': 'application/json'});
      }

      final response = await inner(request);
      if (response.statusCode < 500) {
        final body = await response.readAsString();
        await redis.setex('idem:$key', 3600, body);
        return response.change(body: body);
      }
      return response;
    };
  };
}
```

## Reading from / writing to `RequestContext`

Middleware can fetch the framework context exactly like a handler:

```dart
Middleware enforceTenantMiddleware() {
  return (Handler inner) {
    return (Request request) async {
      final ctx = RequestContext.maybeOf(request);
      final tenant = ctx?.principal?.claims['tenantId'] as String?;
      if (tenant == null) throw Forbidden('Tenant claim missing');
      ctx!.extra['tenantId'] = tenant;
      return inner(request);
    };
  };
}
```

Handlers can read your scratch values via `ctx.extra['tenantId']`.

`RequestContext.maybeOf(request)` is `null` only outside the
framework pipeline (e.g. in raw unit tests that bypass `GisilaApp`).
In production it's always set by the request-id middleware.

## Short-circuiting

To answer the request without invoking the inner handler, just
return a `Response` instead of calling `await inner(request)`:

```dart
Middleware maintenanceMode(bool enabled) {
  return (Handler inner) {
    return (Request request) async {
      if (enabled && !request.url.path.startsWith('health')) {
        return Response(503,
            body: '{"error":{"status":503,"code":"maintenance"}}',
            headers: const {'content-type': 'application/json'});
      }
      return inner(request);
    };
  };
}
```

To raise a typed error from middleware, throw an `HttpException` -
the framework's error mapper handles it just like a handler-thrown
one:

```dart
if (request.headers['x-required-feature'] == null) {
  throw BadRequest('Feature flag header missing',
      code: 'missing_feature_header');
}
```

## Recipe: structured request tracing

Attach an OpenTelemetry span around every request:

```dart
Middleware tracingMiddleware(Tracer tracer) {
  return (Handler inner) {
    return (Request request) async {
      final span = tracer.startSpan(
        '${request.method} ${request.url.path}',
        attributes: {
          'http.method': request.method,
          'http.target': request.url.path,
        },
      );
      try {
        final response = await inner(request);
        span.setAttribute('http.status_code', response.statusCode);
        if (response.statusCode >= 500) span.setStatus(Status.error);
        return response;
      } catch (e, st) {
        span.recordException(e, stackTrace: st);
        span.setStatus(Status.error);
        rethrow;
      } finally {
        span.end();
      }
    };
  };
}
```

Register globally:

```dart
app.use(tracingMiddleware(tracer));
```

## Recipe: per-tenant rate limiting

The built-in `RateLimitConfig.keyExtractor` lets you change the
bucket key:

```dart
config: AppConfig(
  rateLimit: RateLimitConfig(
    requestsPerMinute: 600,
    burstSize: 1000,
    keyExtractor: (request) {
      final ctx = RequestContext.maybeOf(request);
      final tenant = ctx?.principal?.claims['tenantId'] as String?;
      return tenant ?? request.headers['x-forwarded-for'] ?? 'global';
    },
  ),
),
```

For multi-process / distributed rate limiting, write your own
middleware backed by Redis:

```dart
Middleware redisRateLimit(RedisClient redis, {int rpm = 600}) {
  return (Handler inner) {
    return (Request request) async {
      final key = 'rl:${request.headers['x-forwarded-for']}';
      final count = await redis.incr(key);
      if (count == 1) await redis.expire(key, 60);
      if (count > rpm) throw TooManyRequests();
      return inner(request);
    };
  };
}
```

## Compression and ETags

Both are built in and off by default:

```dart
AppConfig(
  compression: const CompressionConfig(),   // gzip
  etags: const EtagConfig(),                // ETag + 304 Not Modified
);
```

**Compression** gzips responses for clients that send
`Accept-Encoding: gzip` when the MIME type is compressible (JSON, text,
JavaScript, XML, SVG by default; never `text/event-stream`) and the body
is at least `minBytes` (1 KiB). Streams of unknown length are compressed
as they're written. It adds `Vary: Accept-Encoding` and leaves alone any
response that already has a `Content-Encoding`, so a route can send
`Content-Encoding: identity` to opt out. Leave it off when your reverse
proxy compresses already.

Compressing a page that holds a secret next to text the caller controls
can leak the secret over TLS (the BREACH attack). Use `shouldCompress` to
leave such responses out:

```dart
CompressionConfig(
  shouldCompress: (request, response) => !request.url.path.startsWith('auth/'),
)
```

**ETags** hash the body of successful `GET` / `HEAD` responses up to
`maxBytes` (1 MiB) and answer `304 Not Modified` with no body when the
request's `If-None-Match` matches. A handler's own `ETag` is kept and
honoured, and `Cache-Control: no-store` responses are skipped. With
compression on, a gzipped response carries the weak form `W/"..."` of
the same tag, which still matches.

The ETag still means the handler ran: it saves bandwidth, not work. To
skip the work, set an `ETag` yourself from a version column and check
`If-None-Match` before loading anything.

## Recipe: request body validator

Run a JSON-schema validator against every POST/PUT/PATCH body:

```dart
Middleware schemaValidator(Map<String, dynamic> schema) {
  return (Handler inner) {
    return (Request request) async {
      if (request.method case 'GET' || 'DELETE' || 'HEAD' || 'OPTIONS') {
        return inner(request);
      }
      final raw = await request.readAsString();
      final json = jsonDecode(raw);
      final errors = validate(json, schema);
      if (errors.isNotEmpty) {
        throw BadRequest('Schema violation', details: {'errors': errors});
      }
      return inner(request.change(body: raw));
    };
  };
}
```

Register as a named middleware and tag the routes you want to
validate:

```dart
app.registerNamedMiddleware('schema-orders',
    schemaValidator(loadSchema('orders.json')));

@Post('/orders')
@UseMiddleware('schema-orders')
@Permissions({'orders:write'})
Future<Order> create(Order body) async => ...;
```

## Testing middleware

Middleware is a one-argument function returning a one-argument
function - trivial to test in isolation:

```dart
test('maintenanceMode short-circuits non-health paths', () async {
  final mw = maintenanceMode(true);
  final handler = mw((req) async => Response.ok('hit'));
  final res = await handler(Request('GET', Uri.parse('http://x/users')));
  expect(res.statusCode, 503);
});
```

For middleware that depends on `RequestContext` / `GisilaApp`,
construct them by hand:

```dart
final app = GisilaApp(config: AppConfig(logRequests: false));
final req = Request('GET', Uri.parse('http://x/'),
    context: {kAppKey: app,
              kContextKey: RequestContext(requestId: 't', request: ...)});
```

See [testing.md](testing.md) for more end-to-end patterns.
