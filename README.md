# gisila

> A small, opinionated **MVC** web framework for Dart on top of
> **Shelf**. Annotation-driven routing, typed input forms,
> request-scoped services, declarative permissions, per-route
> configuration (rate limit / timeout / middleware), pluggable
> database, structured logging, and a tiny `build_runner` code
> generator.

```dart
@Controller('/users')
@RequireAuth()
class UsersController {
  @Get('/me')
  Future<Map<String, Object?>> me(RequestContext ctx) async =>
      {'id': ctx.principal!.id};

  // Typed form (no `Request`, no manual body parsing) + auto-injected
  // service (no constructor wiring at the controller).
  @Post(
    '/',
    config: RouteConfig(
      rateLimit: RateLimitConfig(requestsPerMinute: 30),
    ),
  )
  @Permissions({'users:write'})
  Future<User> create(RegisterForm form, UserService users) =>
      users.register(
        email: form.email.value!,
        password: form.password.value!,
        name: form.name.value!,
      );

  @Delete('/{id}')
  @AnyPermission({'admin', 'users:write'})
  Future<void> delete(String id, UserService users) => users.delete(id);

  @Get('/admin/audit')
  @Roles({'admin'})
  Future<Map<String, Object?>> audit(UserService users) =>
      users.audit();

  @Get('/ping')
  @Public()
  Future<Map<String, Object?>> ping() async => {'status': 'ok'};
}
```

```dart
class RegisterForm extends Form {
  final email    = EmailField(name: 'email',    required: true);
  final password = PasswordField(name: 'password', required: true);
  final name     = StringField(name: 'name',    required: true, maxLength: 100);

  @override
  List<FormField<Object?>> collectFields() => [email, password, name];
}
```

```dart
final app = GisilaApp(
  config: AppConfig(
    logLevel: LogLevel.info,
    logFormat: LogFormat.text,
    cors: const CorsConfig(),
    // Baseline applied to every route; method-level `config:` overrides.
    defaultRouteConfig: const RouteConfig(
      rateLimit: RateLimitConfig(requestsPerMinute: 300),
      timeout: Duration(seconds: 15),
    ),
    // Optional: per-request DB session via your DatabaseProvider.
    // database: GisilaOrmDatabaseProvider(...),
    // dbErrorMapper: PostgresErrorMapper(),
    authenticator: const StaticTokenAuthenticator({
      'admin-token': Principal(
        id: 'admin',
        roles: {'admin'},
        permissions: {'users:read', 'users:write'},
      ),
    }),
  ),
);

app.registerService<UserService>(UserService.new);
app.registerController(attacher: UsersController().attachToApp);

await app.start(host: '0.0.0.0', port: 8080);
```

Routes, permission gates, body parsing into typed forms, service
injection, request-id propagation, per-route rate limit / timeout,
per-request DB session, structured access log, and
`400 / 401 / 403 / 404 / 409 / 422 / 500` error envelopes are all
wired automatically. No `handleRequest(...)` wrapper, no
`request.contextDb`, no inline permission checks - the framework owns
the pipeline; controllers stay thin.

> **New here?** Walk through the
> [10-minute tutorial](GETTING_STARTED.md) — it takes you from an
> empty directory to a running protected API.

## Documentation

| Topic | Read when you need to… |
| ----- | ---------------------- |
| [Getting started](GETTING_STARTED.md) | Build your first app step by step. |
| [Controllers and routing](doc/controllers-and-routing.md) | Understand annotations, params, responses. |
| [Permissions](doc/permissions.md) | Gate routes with auth, roles, or scopes. |
| [Authentication](doc/authentication.md) | Use the built-in `JwtAuthenticator`, or wire API keys / sessions / custom resolvers. |
| [Middleware](doc/middleware.md) | Add CORS / rate-limit / tracing / custom logic. |
| [Logging](doc/logging.md) | Configure formats, custom sinks, redaction. |
| [Configuration](doc/configuration.md) | Reference for every `AppConfig` field. |
| [Error handling](doc/error-handling.md) | Use the `HttpException` hierarchy properly. |
| [Testing](doc/testing.md) | Test controllers / guards / middleware with `GisilaTestClient`. |
| [Cookbook](doc/cookbook.md) | Copy-paste recipes for common needs. |

A topic index lives in [docs/README.md](doc/README.md).

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
  HTTP-method route annotations. Each carries the path, an optional
  success status code, and an optional `config: RouteConfig` overlay.
* `@UseRouteConfig(RouteConfig(...))` — controller-wide route defaults.
* `@Path / @Query / @Header / @Body` — parameter-source overrides
  (rarely needed; the generator infers from name and type).
* `Form` subclasses — typed input validation; parameters of any
  `Form`-derived type are bound from the request body automatically.
* `Service` subclasses — request-scoped business-logic classes;
  parameters of any `Service`-derived type are instantiated and
  injected per request.

### Per-route configuration (RouteConfig)

Every annotation accepts a `config:` parameter. Use it to override
just the fields you care about; the framework merges in this order:

`AppConfig.defaultRouteConfig` ← `@UseRouteConfig` ← guard annotations
(`@RequireAuth` / `@Permissions` / …) ← method-level `config:` ←
named-middleware list.

```dart
@Post(
  '/login',
  config: RouteConfig(
    rateLimit: RateLimitConfig(requestsPerMinute: 10),
    timeout: Duration(seconds: 5),
    contentTypes: {'application/json'},
    maxBodyBytes: 4 * 1024,
  ),
)
@Public()
Future<...> login(LoginForm form, AuthService auth) => ...;
```

### Typed forms

Declare a `Form` subclass per endpoint input shape. Field types know
how to parse + validate themselves and the framework returns a fully
populated typed object - only fields you declared, values already
parsed (never raw strings):

```dart
class LoginForm extends Form {
  final email    = EmailField(name: 'email',    required: true);
  final password = StringField(name: 'password', required: true);
  final remember = BoolField(name: 'remember');

  @override
  List<FormField<Object?>> collectFields() => [email, password, remember];
}
```

Built-in fields: `StringField`, `IntField`, `DoubleField`, `BoolField`,
`DateTimeField`, `EmailField`, `PasswordField`, `JsonField`,
`FileField`. Validation failures throw `FormValidationException`
which the framework renders as a `400` with a `{fieldName: message}`
map.

### Services

Move business logic + DB access out of controllers:

```dart
class UserService extends Service {
  Future<User> register({required String email, ...}) async {
    final db = ctx.db<Database>();  // request-scoped session
    return Query<User>(...).insert({...}).one(db);
  }
}

// Bootstrap:
app.registerService<UserService>(UserService.new);
```

A fresh service is materialised per request; the framework injects
`RequestContext` (and therefore `db`) before any service method runs.

### Singletons and lifecycle hooks

Things that live as long as the app (a Redis client, a mailer) are
registered once and shared by every request:

```dart
app.registerSingleton(Mailer(smtpUrl));
app.registerSingletonFactory<Redis>(
  (app) => Redis.connect(redisUrl),        // runs in start(), may be async
  dispose: (redis) => redis.close(),       // runs in stop()
);
app.onStart(() => warmCaches());
app.onStop(() => flushMetrics());

// Anywhere with a context:
final redis = ctx.singleton<Redis>();     // or singleton<Redis>() in a Service
```

`start()` creates factory singletons in registration order (a factory
can read earlier ones with `app.singleton<T>()`), then runs the
`onStart` hooks. If one fails, what was set up is torn down and
`start()` throws. `stop()` runs the `onStop` hooks and disposes the
singletons in reverse order. When you serve through `buildHandler()`
yourself (tests), call `await app.init()` first and `await app.stop()`
after.

### Database

Implement `DatabaseProvider<S>` for your driver (a `gisila_orm`
adapter ships with the consumer apps). The framework runs a per-
request session middleware that opens a session on entry, closes /
commits / rolls back based on the response status, and exposes the
session through `ctx.db<S>()`.

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

| Middleware              | Configured via                              |
| ----------------------- | ------------------------------------------- |
| Request ID propagation  | `AppConfig.requestIdHeader`                 |
| DB session lifecycle    | `AppConfig.database`                        |
| Structured access log   | `logRequests` + logger                      |
| CORS (incl. pre-flight) | `AppConfig.cors`                            |
| Rate limiting (global)  | `AppConfig.rateLimit`                       |
| Rate limiting (route)   | `RouteConfig.rateLimit`                     |
| Body-size limit         | `AppConfig.maxRequestBodyBytes` / `RouteConfig.maxBodyBytes` |
| Request timeout         | `AppConfig.requestTimeout` / `RouteConfig.timeout` |
| Content-type whitelist  | `RouteConfig.contentTypes` / `allowedContentTypesMiddleware` |
| Error mapping           | always-on (HttpException, FormValidationException, EndpointException, DbErrorMapper, fallback) |
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

The framework's error middleware (installed unconditionally - no need
for any user-land `handleRequest` wrapper) maps:

| Exception                  | Response                                |
| -------------------------- | --------------------------------------- |
| `HttpException` subclasses | `{error: {status, code, message}}` at the declared status code |
| `FormValidationException`  | `400` with `{error: {…, details: {fieldName: msg, …}}}` |
| `EndpointException`        | User-supplied status + body             |
| Errors recognised by `AppConfig.dbErrorMapper` | Whatever the mapper returns |
| Everything else            | `500 Internal Server Error` envelope    |

Built-in `HttpException` subclasses: `BadRequest` (400),
`Unauthorized` (401), `Forbidden` (403), `NotFound` (404),
`Conflict` (409), `TooManyRequests` (429),
`InternalServerError` (500).

---

## Parameter inference rules

The generator picks a source for each method parameter in this order:

1. An explicit annotation: `@Path`, `@Query`, `@Header`, `@Body`.
2. A `RequestContext` parameter receives the framework-managed context.
3. A `shelf.Request` parameter is passed through untouched.
4. A `Form` subclass is bound from the request body via `bindForm`.
5. A `Service` subclass is resolved via `ctx.service<T>()` (the
   framework instantiates a fresh instance per request and attaches
   `ctx` before injection).
6. A parameter whose name matches a `{placeholder}` in the route path
   becomes a **path** parameter.
7. A primitive (`String`, `int`, `double`, `num`, `bool`, `DateTime`)
   becomes a **query** parameter.
8. Anything else is the **request body** (at most one per method).
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
  DatabaseProvider? database,             // null = no DB session middleware
  DbErrorMapper? dbErrorMapper,           // null = no driver-specific mapping
  String requestIdHeader = 'X-Request-Id',
  CorsConfig? cors,                       // null = CORS disabled
  RateLimitConfig? rateLimit,             // null = no global rate limiting
  RouteConfig defaultRouteConfig = RouteConfig.empty,
  ErrorHandler? errorHandler,             // null = default 500
  String serverHeader = 'gisila/0.2.0',
  bool poweredByHeader = true,
  Duration? requestTimeout,               // null = no global timeout
  int? maxRequestBodyBytes,               // null = unlimited
  Map<String, Object?> extra = const {},
})
```

### RouteConfig

```dart
RouteConfig({
  RateLimitConfig? rateLimit,    // per-route rate limit
  Duration? timeout,             // per-route timeout
  int? maxBodyBytes,             // per-route body cap
  Set<String>? contentTypes,     // per-route content-type whitelist
  CorsConfig? cors,              // per-route CORS overrides
  List<Middleware> middleware,   // extra per-route Shelf middleware
  bool requireAuth = false,
  Set<String> permissions    = {},   // ALL must be present
  Set<String> anyPermission  = {},   // at least one
  Set<String> roles          = {},   // at least one
  int? statusCode,               // override success status
  bool isPublic = false,         // disable all auth/permission checks
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
access the authenticated principal, the request ID, the per-request
database session, the service resolver, and an open scratch-space for
middleware:

```dart
@Get('/me')
@RequireAuth()
Future<User> me(RequestContext ctx) async {
  print(ctx.requestId);                 // unique id from X-Request-Id
  print(ctx.principal!.id);             // authenticated user id
  print(ctx.isAuthenticated);           // true
  print(ctx.extra['tenant']);           // ad-hoc middleware data
  final db = ctx.db<Database>();        // request-scoped DB session
  final svc = ctx.service<UserService>(); // request-scoped service
  return svc.find(ctx.principal!.id);
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
curl -X POST \
  -H 'content-type: application/json' \
  -d '{"name":"alice","email":"a@b.com","password":"hunter2!"}' \
  http://localhost:8080/users/
```

---

## Version compatibility

The generator is pinned to the legacy `analyzer` element API
(`ClassElement`, `ParameterElement`) preserved in `analyzer 7.x`.
An `analyzer 8+` build will follow once `source_gen` upstream
stabilises on the new `Element2` model.
