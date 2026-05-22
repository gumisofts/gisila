# Changelog

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
