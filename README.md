# gisila

> A small, opinionated **Shelf**-based web framework for Dart with
> annotation-driven routing, declarative permission/role checks,
> pluggable middleware, configurable structured logging, and a tiny
> `build_runner` code generator.

```dart
@Controller('/users')
@RequireAuth()
class UsersController {
  @Get('/me')
  Future<Map<String, Object?>> me(RequestContext ctx) async =>
      {'id': ctx.principal!.id};

  @Post('/')
  @Permissions({'users:write'})
  Future<User> create(@Body() CreateUser body) async => repo.create(body);

  @Delete('/{id}')
  @AnyPermission({'admin', 'users:write'})
  Future<void> delete(String id) async => repo.delete(id);

  @Get('/admin/audit')
  @Roles({'admin'})
  Future<Map<String, Object?>> audit() async => repo.audit();

  @Get('/ping')
  @Public()
  Future<Map<String, Object?>> ping() async => {'status': 'ok'};
}
```

```dart
final app = GisilaApp(
  config: AppConfig(
    logLevel: LogLevel.info,
    logFormat: LogFormat.text,
    cors: const CorsConfig(),
    rateLimit: const RateLimitConfig(requestsPerMinute: 300),
    authenticator: const StaticTokenAuthenticator({
      'admin-token': Principal(
        id: 'admin',
        roles: {'admin'},
        permissions: {'users:read', 'users:write'},
      ),
    }),
  ),
)..registerController(attacher: UsersController().attachToApp);

await app.start(host: '0.0.0.0', port: 8080);
```

Routes, permission gates, JSON body decoding, request-id propagation,
per-request log line, and `401 / 403 / 400 / 500` error envelopes are
all wired automatically.

> **New here?** Walk through the
> [10-minute tutorial](GETTING_STARTED.md) — it takes you from an
> empty directory to a running protected API.

## Documentation

| Topic | Read when you need to… |
| ----- | ---------------------- |
| [Getting started](GETTING_STARTED.md) | Build your first app step by step. |
| [Controllers and routing](docs/controllers-and-routing.md) | Understand annotations, params, responses. |
| [Permissions](docs/permissions.md) | Gate routes with auth, roles, or scopes. |
| [Authentication](docs/authentication.md) | Wire JWT / API keys / sessions / custom resolvers. |
| [Middleware](docs/middleware.md) | Add CORS / rate-limit / tracing / custom logic. |
| [Logging](docs/logging.md) | Configure formats, custom sinks, redaction. |
| [Configuration](docs/configuration.md) | Reference for every `AppConfig` field. |
| [Error handling](docs/error-handling.md) | Use the `HttpException` hierarchy properly. |
| [Testing](docs/testing.md) | Test controllers / guards / middleware. |
| [Cookbook](docs/cookbook.md) | Copy-paste recipes for common needs. |

A topic index lives in [docs/README.md](docs/README.md).

---

## Install

```yaml
# pubspec.yaml
dependencies:
  gisila:
    path: ../gisila   # replace with path / git / pub coordinate

dev_dependencies:
  build_runner: ^2.5.0
```

Add a `part` directive to every file that declares a `@Controller`:

```dart
part 'users_controller.g.dart';
```

Then run:

```bash
dart run build_runner build --delete-conflicting-outputs
```

The generator emits an extension method
`attachToApp(GisilaApp app, Router router, {String prefix = ''})` on
each controller class.

---

## What's in the box

### MVC layout

* `@Controller([path])` — marks a class as a controller and (optionally)
  a path prefix applied to every route in the class.
* `@Get / @Post / @Put / @Patch / @Delete / @Head / @Options` —
  HTTP-method route annotations. Each carries the path and an optional
  success status code.
* `@Path / @Query / @Header / @Body` — parameter-source overrides
  (rarely needed; the generator infers from name and type).

### Declarative permissions

| Annotation              | Effect                                             |
| ----------------------- | -------------------------------------------------- |
| `@RequireAuth()`        | Require an authenticated principal.                |
| `@Permissions({...})`   | Require **all** listed permissions. Implies auth.  |
| `@AnyPermission({...})` | Require **at least one** listed permission.        |
| `@Roles({...})`         | Require at least one listed role. Implies auth.    |
| `@Public()`             | Override class-level guards — route is open.       |

Guards may be placed on the **class** (applies to every route) or on a
**method** (adds to the class-level guards). A method-level `@Public()`
always wins.

### Pluggable authentication

Implement [`Authenticator`](lib/src/runtime/auth/authenticator.dart):

```dart
class JwtAuthenticator extends Authenticator {
  @override
  Future<Principal?> authenticate(Request request) async {
    final token = _bearer(request);
    if (token == null) return null;
    final claims = await _verify(token);
    return Principal(
      id: claims['sub'] as String,
      roles: (claims['roles'] as List).cast<String>().toSet(),
      permissions: (claims['scope'] as String).split(' ').toSet(),
      claims: claims,
    );
  }
}
```

Plug it in via `AppConfig(authenticator: JwtAuthenticator())`.
`StaticTokenAuthenticator` ships for tests and demos.

### Pluggable permission resolution

`AppConfig.permissionResolver` defaults to `ClaimsPermissionResolver`,
which reads `principal.permissions` and `principal.roles` directly.
Swap in your own to consult a database, OPA, or an external API.

### Configurable structured logging

Every request produces a single log line:

```text
2026-05-22T13:07:46Z [INFO ] req=9lnDQXrCjvctjUgG user=admin
   GET /users/admin/audit -> 200 (1ms)
   method=GET path=/users/admin/audit status=200 duration_ms=1
```

`LogFormat.json` emits machine-friendly records:

```json
{
  "ts": "2026-05-22T13:07:46Z",
  "level": "info",
  "msg": "GET /users/admin/audit -> 200 (1ms)",
  "requestId": "9lnDQXrCjvctjUgG",
  "principalId": "admin",
  "method": "GET",
  "path": "/users/admin/audit",
  "status": 200,
  "duration_ms": 1
}
```

| `AppConfig` field   | Default            | Purpose                                |
| ------------------- | ------------------ | -------------------------------------- |
| `logger`            | `ConsoleLogger`    | Pluggable sink — implement your own.   |
| `logLevel`          | `LogLevel.info`    | Minimum severity emitted.              |
| `logFormat`         | `LogFormat.text`   | `text` or `json`.                      |
| `logRequests`       | `true`             | Per-request access log.                |
| `logRequestBody`    | `false`            | Capture (truncated) request body.      |
| `logResponseBody`   | `false`            | Capture (truncated) response body.     |

### Bundled middleware

| Middleware              | Configured via                  |
| ----------------------- | ------------------------------- |
| Request ID propagation  | `AppConfig.requestIdHeader`     |
| Structured access log   | `logRequests` + logger          |
| CORS (incl. pre-flight) | `AppConfig.cors`                |
| Rate limiting           | `AppConfig.rateLimit`           |
| Body-size limit         | `AppConfig.maxRequestBodyBytes` |
| Request timeout         | `AppConfig.requestTimeout`      |
| Error mapping           | `AppConfig.errorHandler`        |
| Server/X-Powered-By     | `AppConfig.serverHeader` / `poweredByHeader` |

### Per-route named middleware

Register middleware by name once, then reference it from any annotation:

```dart
app.registerNamedMiddleware('audit', auditMiddleware());

@UseMiddleware('audit')
@Post('/')
@Permissions({'users:write'})
Future<User> create(CreateUser body) async => repo.create(body);
```

Class-level `@UseMiddleware` applies to every route in the controller.
Multiple annotations stack in declaration order.

### Error handling

Any `HttpException` thrown inside a handler is automatically rendered as:

```json
{
  "error": {
    "status": 404,
    "code": "not_found",
    "message": "User \"42\" not found"
  }
}
```

Built-in subclasses: `BadRequest` (400), `Unauthorized` (401),
`Forbidden` (403), `NotFound` (404), `Conflict` (409),
`TooManyRequests` (429), `InternalServerError` (500).

---

## Parameter inference rules

The generator picks a source for each method parameter in this order:

1. An explicit annotation: `@Path`, `@Query`, `@Header`, `@Body`.
2. A `RequestContext` parameter receives the framework-managed context.
3. A `shelf.Request` parameter is passed through untouched.
4. A parameter whose name matches a `{placeholder}` in the route path
   becomes a **path** parameter.
5. A primitive (`String`, `int`, `double`, `num`, `bool`, `DateTime`)
   becomes a **query** parameter.
6. Anything else is the **request body** (at most one per method).
   Decoded as JSON and hydrated via the type's `fromJson` factory if
   one exists; `List<T>` is walked element-by-element.

Nullable types (`int?`, `String?`) become optional automatically.

---

## Response handling

| Return type | Behavior |
| ----------- | -------- |
| `Response` / `Future<Response>` | Passed through untouched. |
| `void` / `Future<void>` | Empty body, declared status code (`204` for `@Delete`). |
| Any other type | JSON-encoded via `toJson()` (recursive for `List<T>` / `Map<String, V>`). |

---

## AppConfig reference

```dart
AppConfig({
  Logger? logger,                         // custom sink; defaults to ConsoleLogger
  LogLevel logLevel = LogLevel.info,
  LogFormat logFormat = LogFormat.text,   // text | json
  bool logRequests = true,
  bool logRequestBody = false,
  bool logResponseBody = false,
  Authenticator authenticator = const NullAuthenticator(),
  PermissionResolver permissionResolver = const ClaimsPermissionResolver(),
  String requestIdHeader = 'X-Request-Id',
  CorsConfig? cors,                       // null = CORS disabled
  RateLimitConfig? rateLimit,             // null = no rate limiting
  ErrorHandler? errorHandler,             // null = default 500
  String serverHeader = 'gisila/0.1.0',
  bool poweredByHeader = true,
  Duration? requestTimeout,               // null = no timeout
  int? maxRequestBodyBytes,               // null = unlimited
  Map<String, Object?> extra = const {},
})
```

### CorsConfig

```dart
CorsConfig({
  Set<String> allowedOrigins = const {'*'},
  Set<String> allowedMethods = const {'GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'},
  Set<String> allowedHeaders = const {'Content-Type', 'Authorization', 'X-Request-Id'},
  Set<String> exposedHeaders = const {},
  bool allowCredentials = false,
  Duration maxAge = const Duration(hours: 1),
})
```

### RateLimitConfig

```dart
RateLimitConfig({
  int requestsPerMinute = 120,
  int? burstSize,          // defaults to requestsPerMinute
  String Function(Request)? keyExtractor,  // defaults to IP
})
```

---

## RequestContext

Controller methods may accept a `RequestContext` as a parameter to
access the authenticated principal, the request ID, and an open
scratch-space for middleware:

```dart
@Get('/me')
@RequireAuth()
Future<User> me(RequestContext ctx) async {
  print(ctx.requestId);          // unique id from X-Request-Id
  print(ctx.principal!.id);      // authenticated user id
  print(ctx.isAuthenticated);    // true
  print(ctx.extra['tenant']);    // app-level middleware can stash data here
  return repo.find(ctx.principal!.id);
}
```

---

## Running the example

```bash
cd example
dart pub get
dart run build_runner build --delete-conflicting-outputs
dart run bin/server.dart

# In another terminal:
curl -H 'Authorization: Bearer reader-token' http://localhost:8080/users/me
curl -X POST -H 'Authorization: Bearer writer-token' \
  -H 'content-type: application/json' \
  -d '{"name":"alice","email":"a@b.com"}' \
  http://localhost:8080/users/
```

---

## Version compatibility

The generator is pinned to the legacy `analyzer` element API
(`ClassElement`, `ParameterElement`) preserved in `analyzer 7.x`.
An `analyzer 8+` build will follow once `source_gen` upstream
stabilises on the new `Element2` model.
