# Changelog

## 0.3.0 — 2026-10-28 — pipeline hardening (BREAKING)

- Security: code generation matched annotations by name and by any library
  URI containing "gisila", so a `Public` from another package (say
  `gisila_extras`) made a route public and dropped the class's
  `@RequireAuth`. Annotations must now come from `package:gisila/`.
- `@Get('/')` under `@Controller('/users')` answers both `/users/` and
  `/users` (it used to 404 on `/users`).
- `stop(drainTimeout:)` waits for in-flight requests (30 s by default) and
  then force-closes; it now also calls the new `DatabaseProvider.dispose()`.
  `start(stopOnSignals: true)` stops gracefully on SIGINT/SIGTERM.
  `AppConfig.healthCheckPath` (e.g. `'/healthz'`) serves a liveness probe
  outside auth and routing, with an optional `healthCheck` (503 on false).
- Defaults: no `Server` header and no `X-Powered-By` unless set
  (`serverHeader`, `poweredByHeader`). Unmatched routes answer a JSON 404
  in the error envelope. In JSON logs, fields can no longer overwrite
  `ts`, `level`, `msg`.
- Docs: the pipeline order in `doc/middleware.md` matches the code, and the
  library example uses `registerController(attacher: ...)`.

- Rate limits can be shared across isolates and processes:
  `AppConfig.rateLimitStore` takes a `RateLimitStore` (implement `take` on
  Redis, for example); the default `InMemoryRateLimitStore` keeps today's
  per-isolate behaviour. Generated routes pass `gisilaRoute(routeId:
  'METHOD path')` so each route's buckets have the same name in every
  isolate. `rateLimitMiddleware` takes optional `store` and `scope`.

- Fix: `RouteConfig(timeout: ...)` and `CorsConfig(maxAge: ...)` set in an
  annotation were dropped by code generation on current Dart SDKs (the
  emitter read the `Duration` constant's old private field). Routes now get
  their timeout.
- Tests: `pipeline_integration_test` runs a generated controller
  (`test/fixtures/guarded_controller.dart`) through `buildHandler()`:
  guards, form and parameter binding, route timeout and rate limit, error
  mapping, CORS pre-flight, request ids. `generated_golden_test` fails when
  the generated code for that fixture changes (`GISILA_UPDATE_GOLDEN=1` to
  accept it).

### Security

* **Rate limiter keys on the real client.** The default key is now the
  socket's peer address (it used to be the same string for every client).
  `X-Forwarded-For` is only trusted from `AppConfig.trustedProxies` /
  `RateLimitConfig.trustedProxies` (exact IPs or CIDR), which defaults to
  loopback so apps behind a local nginx/Caddy keep working. Idle buckets are
  swept and the map is capped by `RateLimitConfig.maxBuckets`. `Retry-After`
  is now the real wait. New helper: `clientAddress(request, trustedProxies:)`.
* **Body size limits hold for chunked bodies.** `maxRequestBodyBytes` /
  `RouteConfig.maxBodyBytes` now meter the body stream and fail with `413`
  (`PayloadTooLarge`) as soon as the cap is crossed. Multipart parsing caps
  parts (`maxParts`, default 1000) and text field size (`maxFieldBytes`,
  default 1 MiB).
* **Route guards fail closed.** `gisilaRoute` uses the app it was built with,
  so guards hold even when the router is mounted outside `buildHandler()`.
  `guardRequest` returns `500` for a guarded route with no `GisilaApp` on the
  request (it used to let the call through).
* Incoming `X-Request-Id` values are only reused when they are 1–128
  characters of `[A-Za-z0-9._:-]`.
* **CORS (breaking for one config).** `CorsConfig(allowCredentials: true)`
  with the default `'*'` origins now throws `ArgumentError` when the
  middleware is built, instead of echoing every origin with credentials;
  list the allowed origins. Only real pre-flights (`OPTIONS` with `Origin`
  and `Access-Control-Request-Method`) are answered by the middleware; one
  from a disallowed origin gets `403`, and other `OPTIONS` requests reach
  the router. Non-wildcard configs send `Vary: Origin` on every response.
* **Authenticator errors stay on the server.** An exception thrown by the
  `Authenticator` used to be sent to the client as the 401 message (JWT or
  database details). It is now a plain `401 Authentication required`, logged
  at warning level; an `HttpException` 401/403 the authenticator throws on
  purpose is still sent as is.

### Fixed

* Multi-value response headers (several `Set-Cookie`) are no longer joined
  into one by the CORS, request-id and server-header middleware.
* The DB session middleware now runs inside CORS, rate limiting, the body cap
  and the error mapper: pre-flights and rejected requests don't take a pooled
  connection, and a failing `DatabaseProvider.open` is a normal JSON `500`.
  A thrown `HttpException` below 500 or a form validation error still closes
  the session with `ok: true`.
* Timeouts: a timed-out handler keeps running (Dart can't abort it), so the
  session now stays open until it finishes and is then closed with
  `ok: false`. `RequestContext.cancellation` is cancelled on timeout; check
  `isCancelled` or call `throwIfCancelled()` in long handlers. A
  `TimeoutException` thrown by the handler itself is no longer reported as
  `504`.
* CORS responses that echo a specific origin send `Vary: Origin`.
* `@Public` survives later config layers: a method `config:`, named
  middleware or an app-wide `defaultRouteConfig` with `requireAuth` no longer
  turns a public route back into a login-required one. A later layer that
  adds a guard itself still wins.
* Generated handlers only wrap parameter binding in the `TypeError` /
  `FormatException` → `400` catch. An error thrown by the controller method
  itself used to come back as a `400` echoing its text; it now reaches the
  error handler as a `500`. Regenerate with `build_runner`.
* `RateLimitConfig.keyExtractor` set in a route's `config:` (a top-level
  function or a static method) is now carried into the generated code; the
  generator used to drop it, so every route keyed on the client address.
* JSON responses send an enum without a `toJson()` as its `name` (`"red"`);
  they used to send `toString()` (`"Color.red"`).
* An empty query value (`?page=`) counts as not given for non-string
  parameters, so an optional `int? page` is `null` instead of a `400`.
  Strings keep `''`.

## 0.2.0 — MVC overhaul (BREAKING)

This release reshapes gisila into a proper MVC framework. Every consumer must
update their bootstrap, controllers, and forms. There is no deprecation
period; the old `form()` helper and the `__inner(Request)` generated style
are gone.

### Added

* **Typed `Form` / `FormField` hierarchy** (`lib/src/runtime/forms/`). Declare a
  `Form` subclass with one `FormField` per expected input (`StringField`,
  `IntField`, `DoubleField`, `BoolField`, `DateTimeField`, `EmailField`,
  `PasswordField`, `JsonField`, `FileField`). The framework parses, validates,
  and gives the controller a fully-populated typed instance. Only declared
  fields are read; values are the parsed type, never the raw `String`.
* **`RouteConfig`** (`lib/src/runtime/route_config.dart`). Per-route rate
  limit, timeout, max body size, content-type whitelist, CORS overrides,
  extra middleware, declarative permissions/roles, and success status code
  - all merged from `AppConfig.defaultRouteConfig` ← `@UseRouteConfig` ←
  annotation guards ← method-level `config:`.
* **`@UseRouteConfig(RouteConfig(...))`** class-level annotation for
  controller-wide route defaults.
* **`config:` parameter on every HTTP-verb annotation** (`@Get`, `@Post`,
  `@Put`, `@Patch`, `@Delete`, `@Head`, `@Options`).
* **`DatabaseProvider<S>` + `dbSessionMiddleware`** for per-request DB
  session lifecycle. `AppConfig.database` plugs your driver in; controllers
  reach the session as `ctx.db<MySession>()`.
* **`DbErrorMapper`** for translating driver-specific exceptions (e.g.
  Postgres `23xxx` constraint codes) into `HttpException`s before the
  generic `500` mapper.
* **`Service` base class** + `app.registerService<T>(factory)`. A fresh
  service instance is materialised per request, the framework injects
  `RequestContext`, and controllers receive it as a typed method parameter
  (no constructor wiring at the controller).
* **`RequestContext.db<T>()` and `RequestContext.service<T>()`** accessors.
* **`gisilaRoute(...)` runtime helper** that composes the per-route Shelf
  pipeline (rate limit, content-type, timeout, body cap, custom middleware,
  AuthN/AuthZ) and dispatches to a typed handler.
* **`EndpointException`** for arbitrary `{statusCode, body}` errors; the
  default error middleware renders it as the user-supplied JSON envelope.
* **`FormValidationException` mapping** in the default error middleware
  produces a structured `400` with a per-field error map.

### Changed

* **`@Get` / `@Post` / etc. now accept `config: RouteConfig?`.** The
  positional `path` argument is unchanged.
* **`@Controller` is unchanged**, but you can pair it with the new
  `@UseRouteConfig(...)` for controller-wide defaults.
* **`@RequireAuth` / `@Permissions` / `@AnyPermission` / `@Roles` /
  `@Public`** are unchanged in shape, but the generator now folds them
  into the per-route `RouteConfig` and auth runs as a real middleware.
* **`RequestContext`** carries a service resolver in addition to the
  principal, requestId, request, extra; new methods `db<T>()` and
  `service<T>()`.
* **`AppConfig`** gains `database`, `dbErrorMapper`, `defaultRouteConfig`.
* **Default `serverHeader`** bumped to `gisila/0.2.0`.

### Removed (BREAKING)

* **`form(request, fields: [...])` map helper.** Replaced by the typed
  `Form` / `FormField` hierarchy + `bindForm<F>(request, F.new)`.
  Migration: extract the per-endpoint field lists into a `Form` subclass
  per endpoint, and read values via `form.fieldName.value`.
* **`FieldValidator<T>` (old class) / `EmailVerifier` / `Field` /
  `emailFieldValidator` / `nameFieldValidator`.** Use `StringField` with
  validators, `EmailField`, `PasswordField`, etc.
* **`FieldValidationException`.** Replaced by `FormValidationException`
  which carries `errors: Map<String, String>` (the old `error` was
  `Map<String, dynamic>`).
* **Inline `guardRequest(...)` calls in generated handlers.** AuthN/AuthZ
  now runs as a per-route middleware composed from `RouteConfig`.
* **`__inner(Request request)` closure in generated handlers.** Replaced
  by a typed `handler: (RequestContext ctx) async { ... }` passed to
  `gisilaRoute(...)`.

### Migration

1. Replace `form(request, fields: [...])` callsites with a typed `Form`
   subclass and accept it as a controller parameter.
2. Add `config: RouteConfig(...)` to route annotations that need
   per-route limits or middleware.
3. Define a `DatabaseProvider` for your driver, set
   `AppConfig.database`, drop hand-written `Database.connect(...)` calls
   from controllers, and read sessions via `ctx.db<MySession>()`.
4. Move business logic + DB access into `Service` subclasses, register
   them with `app.registerService<T>(T.new)`, and accept them as
   controller parameters.
5. Delete any user-land `handleRequest(...)` wrapper - the framework's
   default error middleware now maps `HttpException`,
   `FormValidationException`, `EndpointException`, and (via
   `DbErrorMapper`) driver-specific errors.

## 0.1.1

* Unified version with the rest of the gisila ecosystem (`gisila_doc`, `gisila_orm`, `gisila_studio`).
* Added `forms.dart`: `FieldValidator`, `EmailVerifier`, and the `form()` helper for declarative request-body validation across JSON, `application/x-www-form-urlencoded`, and `multipart/form-data`.
* Added `content_type` middleware: rejects `POST`/`PUT`/`PATCH` requests with an unsupported `Content-Type` with a `415 Unsupported Media Type` JSON envelope.
* Added `body_parser.dart`: `readJsonBody`, `readFormBody`, and `readBody` helpers for content-type-aware payload parsing; used by the code generator for typed body parameters.
* Added `FormData` abstraction for multipart and URL-encoded payloads.

## 0.1.0

* Initial release.
* MVC-style controllers via `@Controller` + HTTP verb annotations.
* Build-time code generator (`build_runner` /
  `package:gisila_web/builder.dart`) emitting an
  `attachToApp(GisilaApp, Router)` extension method per controller.
* Declarative permission/role gates: `@RequireAuth`, `@Permissions`,
  `@AnyPermission`, `@Roles`, `@Public`.
* Pluggable `Authenticator` / `PermissionResolver` plus a built-in
  `StaticTokenAuthenticator` and `ClaimsPermissionResolver`.
* `GisilaApp` application bootstrap with configurable global pipeline:
  request-id, structured access log (text or JSON), CORS, rate-limit,
  request timeout, body-size limit, error mapping.
* `Logger` abstraction + `ConsoleLogger`; per-request structured
  logging middleware.
* HTTP-error class hierarchy (`HttpException`, `BadRequest`,
  `Unauthorized`, `Forbidden`, `NotFound`, `Conflict`,
  `TooManyRequests`, `InternalServerError`) rendered as a uniform
  JSON envelope.
* JSON codec helpers (`coerce`, `readJsonBody`, `jsonResponse`,
  `emptyResponse`) shared between hand-written and generated code.
* Working `example/` app with user CRUD, role-gated audit endpoint and
  public health-check.
