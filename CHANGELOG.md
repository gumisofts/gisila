# Changelog

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
