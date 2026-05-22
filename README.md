# gisila_web

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
  Future<User> create(CreateUser body) async => repo.create(body);

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
      'admin-token': Principal(id: 'admin', roles: {'admin'},
          permissions: {'users:read', 'users:write'}),
    }),
  ),
)..registerController(attacher: UsersController().attachToApp);

await app.start(host: '0.0.0.0', port: 8080);
```

That is the entire integration: the routes, the permission gates, the
JSON body decoding, the request-id propagation, the per-request log
line and the `401 / 403 / 400 / 500` error envelopes are all wired
automatically.

> **New here?** Walk through the
> [10-minute tutorial](GETTING_STARTED.md) - it takes you from an
> empty directory to a running protected API.

## Documentation

| Topic                                            | Read when you need to...                          |
| ------------------------------------------------ | ------------------------------------------------- |
| [Getting started](GETTING_STARTED.md)            | Build your first app step by step.                |
| [Controllers and routing](docs/controllers-and-routing.md) | Understand annotations, params, responses. |
| [Permissions](docs/permissions.md)               | Gate routes with auth, roles, or scopes.          |
| [Authentication](docs/authentication.md)         | Wire JWT / API keys / sessions / custom resolvers.|
| [Middleware](docs/middleware.md)                 | Add CORS / rate-limit / tracing / custom logic.   |
| [Logging](docs/logging.md)                       | Configure formats, custom sinks, redaction.       |
| [Configuration](docs/configuration.md)           | Reference for every `AppConfig` field.            |
| [Error handling](docs/error-handling.md)         | Use the `HttpException` hierarchy properly.       |
| [Testing](docs/testing.md)                       | Test controllers / guards / middleware.           |
| [Cookbook](docs/cookbook.md)                     | Copy-paste recipes for common needs.              |

A topic index lives in [docs/README.md](docs/README.md).

---

## What's in the box

### MVC layout

* `@Controller([path])` - marks a class as a controller and (optionally)
  a path prefix.
* `@Get / @Post / @Put / @Patch / @Delete / @Head / @Options` -
  HTTP-method route annotations carrying the path and optional success
  status code.
* `@Path / @Query / @Header / @Body` - parameter source overrides
  (rarely needed; the generator infers from name + type).

### Declarative permissions

| Annotation              | Effect                                             |
| ----------------------- | -------------------------------------------------- |
| `@RequireAuth()`        | Require an authenticated principal.                |
| `@Permissions({...})`   | Require **all** listed permissions. Implies auth.  |
| `@AnyPermission({...})` | Require **at least one** listed permission.        |
| `@Roles({...})`         | Require at least one listed role. Implies auth.    |
| `@Public()`             | Override class-level guards: route is open.        |

Guards may be placed on the **class** (applies to every route) or on a
**method** (adds to the class-level guards). A method-level `@Public()`
always wins.

### Pluggable authentication

Implement [`Authenticator`](lib/src/runtime/auth/authenticator.dart):

```dart
class JwtAuthenticator extends Authenticator {
  @override
  Future<Principal?> authenticate(Request request) async {
    final token = _bearer(request); if (token == null) return null;
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

Plug it in via `AppConfig.authenticator`. A `StaticTokenAuthenticator`
ships for tests and demos.

### Pluggable permission resolution

`AppConfig.permissionResolver` defaults to the
`ClaimsPermissionResolver` that reads `principal.permissions` /
`principal.roles`. Swap in your own to consult a database / OPA /
external API.

### Configurable structured logging

Every request becomes a single log line:

```text
2026-05-22T13:07:46Z [INFO ] req=9lnDQXrCjvctjUgG user=admin
   GET /users/admin/audit -> 200 (1ms)
   method=GET path=/users/admin/audit status=200 duration_ms=1
```

`LogFormat.json` emits machine-friendly records:

```json
{"ts":"2026-05-22T13:07:46Z","level":"info","msg":"GET /users/admin/audit -> 200 (1ms)",
 "requestId":"9lnDQXrCjvctjUgG","principalId":"admin",
 "method":"GET","path":"/users/admin/audit","status":200,"duration_ms":1}
```

Knobs on `AppConfig`:

| Field                 | Default            | Purpose                                |
| --------------------- | ------------------ | -------------------------------------- |
| `logger`              | `ConsoleLogger`    | Pluggable sink - implement your own.   |
| `logLevel`            | `LogLevel.info`    | Minimum severity emitted.              |
| `logFormat`           | `LogFormat.text`   | `text` or `json`.                      |
| `logRequests`         | `true`             | Per-request access log.                |
| `logRequestBody`      | `false`            | Capture (truncated) request body.      |
| `logResponseBody`     | `false`            | Capture (truncated) response body.     |

### Bundled middleware

| Middleware              | Configured via            |
| ----------------------- | ------------------------- |
| Request ID propagation  | `AppConfig.requestIdHeader` |
| Structured access log   | `logRequests` + logger     |
| CORS (incl. pre-flight) | `AppConfig.cors`           |
| Rate limiting           | `AppConfig.rateLimit`      |
| Body-size limit         | `AppConfig.maxRequestBodyBytes` |
| Request timeout         | `AppConfig.requestTimeout` |
| Error mapping           | `AppConfig.errorHandler`   |
| Server/X-Powered-By     | `AppConfig.serverHeader`, `poweredByHeader` |

### Per-route named middleware

```dart
app.registerNamedMiddleware('audit', auditMiddleware());

@UseMiddleware('audit')
@Post('/')
@Permissions({'users:write'})
Future<User> create(CreateUser body) async => repo.create(body);
```

Class-level `@UseMiddleware` applies to every route in the controller.
Multiple annotations stack in declaration order.

### Errors

Anything thrown inside a handler that extends `HttpException` is
automatically rendered as:

```json
{
  "error": {
    "status": 404,
    "code": "not_found",
    "message": "User \"42\" not found"
  }
}
```

Built-ins: `BadRequest` (400), `Unauthorized` (401), `Forbidden` (403),
`NotFound` (404), `Conflict` (409), `TooManyRequests` (429),
`InternalServerError` (500). Everything else falls through to the
configured `errorHandler` (defaults to a generic 500 with the exception
logged at `error` level).

---

## Install

`pubspec.yaml`:

```yaml
dependencies:
  gisila_web:
    path: ../gisila_web   # or path / git / pub later

dev_dependencies:
  build_runner: ^2.5.0
```

Then for every file that declares an `@Controller`:

```dart
part 'users_controller.g.dart';
```

and run

```bash
dart run build_runner build --delete-conflicting-outputs
```

The generator emits an extension method
`attachToApp(GisilaApp app, Router router, {String prefix = ''})` on
each controller class.

---

## Parameter inference rules

The generator picks a source for each parameter using these rules, in
order:

1. An explicit annotation: `@Path`, `@Query`, `@Header`, `@Body`.
2. A `RequestContext` parameter receives the framework-managed context.
3. A `shelf.Request` parameter is passed through untouched.
4. A parameter named like a `{placeholder}` in the route path is a
   **path** parameter (`@Get('/users/{id}')` + `String id`).
5. A primitive parameter (`String`, `int`, `double`, `num`, `bool`,
   `DateTime`) is a **query** parameter.
6. Anything else is the **request body** (at most one per method). It
   is decoded as JSON and hydrated via the type's `fromJson` factory
   if one exists; lists of such types are walked element-by-element.

Nullable types (`int?`, `String?`) become optional automatically.

---

## Response handling

* Methods returning `Response` / `Future<Response>` are passed through.
* Methods returning `void` / `Future<void>` send an empty response with
  the declared status code (`204 No Content` by default for `@Delete`).
* Methods returning any other type are JSON-encoded; the type's
  `toJson()` method is called (recursively for `List<T>` /
  `Map<String, V>`).

---

## Running the example

```bash
cd example
dart pub get
dart run build_runner build --delete-conflicting-outputs
dart run bin/server.dart

# in another shell:
curl -H 'Authorization: Bearer reader-token' http://localhost:8080/users/me
curl -X POST -H 'Authorization: Bearer writer-token' \
  -H 'content-type: application/json' \
  -d '{"name":"alice","email":"a@b.com"}' \
  http://localhost:8080/users/
```

---

## Version compatibility

The generator is intentionally pinned to the legacy `analyzer` element
API (`ClassElement`, `ParameterElement`) preserved in `analyzer 7.x`.
We'll publish an `analyzer 8+` build of the generator once
`source_gen` upstream stabilises on the new `Element2` model.
