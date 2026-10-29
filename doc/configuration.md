# Configuration reference

`AppConfig` is the one knob box. Every framework feature is opt-in or
overridable via a field here. This document lists every field, its
default, what flipping it affects, and the trade-offs you should
know.

## Table of contents

- [Quick reference table](#quick-reference-table)
- [Logging](#logging)
- [Authentication / authorisation](#authentication--authorisation)
- [Request id propagation](#request-id-propagation)
- [CORS](#cors)
- [Rate limiting](#rate-limiting)
- [Request timeout](#request-timeout)
- [Body size limit](#body-size-limit)
- [Error handling](#error-handling)
- [Security headers](#security-headers)
- [Server headers](#server-headers)
- [Extra slot](#extra-slot)
- [Common config recipes](#common-config-recipes)

## Quick reference table

| Field                  | Type                      | Default                            | What it does |
| ---------------------- | ------------------------- | ---------------------------------- | ------------ |
| `logger`               | `Logger`                  | `ConsoleLogger`                    | Sink for every framework log call. |
| `logLevel`             | `LogLevel`                | `LogLevel.info`                    | Min severity for the default console logger. |
| `logFormat`            | `LogFormat`               | `LogFormat.text`                   | `text` or `json` for the default console logger. |
| `logRequests`          | `bool`                    | `true`                             | Install the per-request access log middleware. |
| `logRequestBody`       | `bool`                    | `false`                            | Capture (truncated) request bodies. |
| `logResponseBody`      | `bool`                    | `false`                            | Capture (truncated) response bodies. |
| `authenticator`        | `Authenticator`           | `NullAuthenticator`                | Resolves `Principal` from a request. |
| `permissionResolver`   | `PermissionResolver`      | `ClaimsPermissionResolver`         | Checks roles/perms on the principal. |
| `requestIdHeader`      | `String`                  | `'X-Request-Id'`                   | Header used by the request-id middleware. |
| `cors`                 | `CorsConfig?`             | `null`                             | Enables CORS middleware when non-null. |
| `securityHeaders`      | `SecurityHeadersConfig?`  | `SecurityHeadersConfig()`          | HSTS, nosniff, framing, referrer and CSP headers; `null` sends none. |
| `metrics`              | `MetricsConfig?`          | `null`                             | Request metrics and a Prometheus endpoint ([cookbook.md](cookbook.md#metrics-endpoint)). |
| `compression`          | `CompressionConfig?`      | `null`                             | gzips compressible responses ([middleware.md](middleware.md#compression-and-etags)). |
| `etags`                | `EtagConfig?`             | `null`                             | ETags and `304 Not Modified` on `GET` responses. |
| `rateLimit`            | `RateLimitConfig?`        | `null`                             | Enables the token-bucket rate limiter. |
| `requestTimeout`       | `Duration?`               | `null`                             | Aborts requests after this duration (504). |
| `maxRequestBodyBytes`  | `int?`                    | `null`                             | 413 when request body exceeds this. |
| `errorHandler`         | `ErrorHandler?`           | `null`                             | Maps uncaught exceptions to a `Response`. |
| `serverHeader`         | `String`                  | `''`                               | Value of the `Server` response header; empty sends none. |
| `poweredByHeader`      | `bool`                    | `false`                            | Sends `X-Powered-By: gisila`. |
| `extra`                | `Map<String, Object?>`    | `const {}`                         | Free-form slot for user middleware. |

## Logging

```dart
AppConfig(
  logger: ConsoleLogger(format: LogFormat.json),   // optional
  logLevel: LogLevel.info,
  logFormat: LogFormat.text,
  logRequests: true,
  logRequestBody: false,
  logResponseBody: false,
);
```

* If you pass a custom `logger`, the `logLevel` and `logFormat`
  fields are ignored (they only configure the default
  `ConsoleLogger`).
* `logRequestBody` / `logResponseBody` enable body capture for the
  per-request access log. Off by default - bodies can be huge and may
  contain PII.
* See [logging.md](logging.md) for custom sinks, redaction, and
  shipping recipes.

## Authentication / authorisation

```dart
AppConfig(
  authenticator: JwtAuthenticator(secret),
  permissionResolver: DatabasePermissionResolver(db),
);
```

Defaults:

* `authenticator`: `NullAuthenticator` - always returns `null`. Any
  guarded route returns `401`. This is intentional: a brand-new app
  cannot accidentally expose protected routes.
* `permissionResolver`: `ClaimsPermissionResolver` - reads
  `principal.permissions` / `principal.roles`.

Full reference: [authentication.md](authentication.md).

## Request id propagation

```dart
AppConfig(requestIdHeader: 'X-Trace-Id');
```

* If the request carries this header, the value is reused.
* Otherwise a 16-char random id is generated.
* The id is echoed back on the response in the same header and
  attached to every log line as `requestId`.

To use UUIDs (e.g. via the `uuid` package), build your own request-id
middleware and disable the default by **not** changing this field
(the middleware is always on, but you can override globally by adding
your middleware earlier in the pipeline and stripping the header on
the way in).

## CORS

```dart
AppConfig(
  cors: const CorsConfig(
    allowedOrigins: {'https://app.example.com'},
    allowedMethods: {'GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'},
    allowedHeaders: {'Content-Type', 'Authorization', 'X-Request-Id'},
    exposedHeaders: {'X-Request-Id'},
    allowCredentials: true,
    maxAge: Duration(hours: 1),
  ),
);
```

| Field              | Default                                              |
| ------------------ | ---------------------------------------------------- |
| `allowedOrigins`   | `{'*'}` (open)                                       |
| `allowedMethods`   | `{GET, POST, PUT, PATCH, DELETE, OPTIONS}`           |
| `allowedHeaders`   | `{Content-Type, Authorization, X-Request-Id}`        |
| `exposedHeaders`   | `{}`                                                 |
| `allowCredentials` | `false`                                              |
| `maxAge`           | `Duration(hours: 1)`                                 |

Notes:

* When `allowedOrigins` is `{'*'}` and `allowCredentials` is
  `false`, the response sets `Access-Control-Allow-Origin: *`.
* When `allowCredentials` is `true`, the framework echoes the
  request's `Origin` header instead (browsers reject `*` with
  credentials).
* Pre-flight (`OPTIONS`) requests are answered with `204` and the
  configured method/header lists.

## Rate limiting

```dart
AppConfig(
  rateLimit: const RateLimitConfig(
    requestsPerMinute: 120,
    burstSize: 200,
    keyExtractor: null,
  ),
);
```

* `requestsPerMinute` - steady-state allowed rate.
* `burstSize` - max bucket size (defaults to `requestsPerMinute`).
* `keyExtractor` - per-request bucket key. Defaults to
  `X-Forwarded-For` or the peer connection info.

By default each isolate keeps its own token buckets, so a server running
N isolates (or N servers) allows N times the rate. To share one budget,
set `rateLimitStore` to a shared store. `package:gisila_redis` has one:

```dart
AppConfig(
  rateLimit: const RateLimitConfig(requestsPerMinute: 120),
  rateLimitStore: RedisRateLimitStore(GisilaRedis.fromUrl(redisUrl)),
);
```

Any other backend can implement `RateLimitStore.take`.

When the limit is exceeded:

```http
HTTP/1.1 429 Too Many Requests
retry-after: 60
content-type: application/json; charset=utf-8

{"error":{"status":429,"code":"too_many_requests","message":"Rate limit exceeded"}}
```

## Request timeout

```dart
AppConfig(requestTimeout: const Duration(seconds: 15));
```

* The middleware races your handler against the duration.
* If the duration wins, the framework returns `504 Gateway Timeout`
  with a JSON envelope.
* The handler keeps running in the background; if it later writes to
  closed sockets, that's already a no-op.
* Set to `null` (default) to disable.

Useful when a downstream call (DB, HTTP, external API) might hang.
For per-route timeouts, write a small middleware that wraps the
inner handler with `.timeout(Duration(seconds: N))` and register it
via `@UseMiddleware`.

## Body size limit

```dart
AppConfig(maxRequestBodyBytes: 5 * 1024 * 1024);     // 5 MiB
```

* Checks `Content-Length`. Requests larger than the limit get a
  `413 Payload Too Large` JSON envelope **before** any body bytes are
  read.
* Streaming uploads that don't set `Content-Length` aren't checked
  - your handler is responsible.

## Error handling

```dart
AppConfig(
  errorHandler: (error, stack) {
    Sentry.captureException(error, stackTrace: stack);
    return Response.internalServerError(
      body: jsonEncode({'error': {'status': 500, 'code': 'oops'}}),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  },
);
```

* `HttpException` subclasses (`BadRequest`, `Unauthorized`,
  `Forbidden`, `NotFound`, `Conflict`, `TooManyRequests`,
  `InternalServerError`) are always rendered by the framework, even
  when `errorHandler` is set. Use the handler for *everything else*.
* The default handler logs the exception at `error` level and
  returns a generic `500` envelope.
* Full reference: [error-handling.md](error-handling.md).

## Security headers

Every response gets these unless the handler already set the header:

| Header | Default |
| ------ | ------- |
| `Strict-Transport-Security` | `max-age=15552000` (180 days) |
| `X-Content-Type-Options` | `nosniff` |
| `X-Frame-Options` | `DENY` |
| `Referrer-Policy` | `no-referrer` |
| `Content-Security-Policy` | `default-src 'none'; frame-ancestors 'none'` on non-HTML responses; none on `text/html` |

HTML pages (API docs, an admin UI) get no CSP by default because a
policy that doesn't fit the page breaks it. Write one for them with
`htmlContentSecurityPolicy`. Browsers ignore HSTS over plain http, so it
is safe behind a TLS-terminating proxy.

```dart
AppConfig(
  securityHeaders: const SecurityHeadersConfig(
    hsts: HstsConfig(maxAge: Duration(days: 365), includeSubDomains: true),
    frameOptions: null,                      // null leaves a header out
    htmlContentSecurityPolicy: "default-src 'self'",
    extra: {'Permissions-Policy': 'camera=(), geolocation=()'},
  ),
);
```

`securityHeaders: null` turns them all off. A single route can override
one by setting it on its response.

## Server headers

```dart
AppConfig(
  serverHeader: 'my-api/2.3.1',     // empty string disables
  poweredByHeader: false,           // hide X-Powered-By
);
```

* `serverHeader` overrides the `Server` response header. Set to `''`
  to send no `Server` header.
* `poweredByHeader: false` removes the `X-Powered-By: gisila`
  header (handy if you don't want to advertise your stack).

## Extra slot

```dart
final config = AppConfig(
  extra: {
    'featureFlags': loadFlags(),
    'startupTs': DateTime.now().toUtc(),
  },
);
```

Anything in `extra` is reachable from middleware via
`app.config.extra[...]`. Use it as a poor-man's DI container when
you don't want to thread one through the codebase.

## Common config recipes

### Local development

```dart
AppConfig(
  logLevel: LogLevel.debug,
  logFormat: LogFormat.text,
  logRequestBody: true,
  cors: const CorsConfig(allowedOrigins: {'*'}),
);
```

### Production API

Turn on `compression` here unless the reverse proxy compresses, and
`etags` for clients that re-fetch the same resources.

```dart
AppConfig(
  logLevel: LogLevel.info,
  logFormat: LogFormat.json,
  authenticator: JwtAuthenticator(env.jwtSecret),
  permissionResolver: DatabasePermissionResolver(db),
  cors: const CorsConfig(
    allowedOrigins: {'https://app.example.com'},
    allowCredentials: true,
  ),
  rateLimit: const RateLimitConfig(requestsPerMinute: 600),
  requestTimeout: const Duration(seconds: 10),
  maxRequestBodyBytes: 10 * 1024 * 1024,
  serverHeader: 'example-api/${env.gitSha}',
  poweredByHeader: false,
  errorHandler: sentryAwareErrorHandler,
);
```

### Headless service / background worker

```dart
AppConfig(
  logRequests: false,                          // no HTTP, but Logger still useful
  logger: ConsoleLogger(format: LogFormat.json),
);
```

### Tests

```dart
AppConfig(
  logRequests: false,                          // keep test output clean
  logger: ConsoleLogger(level: LogLevel.off),
  authenticator: StaticTokenAuthenticator(
      {'t': const Principal(id: 'u1', permissions: {'all'})}),
);
```
