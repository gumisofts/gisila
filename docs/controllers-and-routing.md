# Controllers and routing

`gisila_web` keeps controllers small and almost free of plumbing. The
build-time generator translates each `@Controller` class into an
extension method that registers routes on a `shelf_router`, decodes
parameters, calls the configured permission guards, invokes your
method, and turns the return value into a JSON response.

This document is the reference for everything in that pipeline.

## Table of contents

- [Anatomy of a controller](#anatomy-of-a-controller)
- [The `@Controller` annotation](#the-controller-annotation)
- [HTTP method annotations](#http-method-annotations)
- [Path patterns](#path-patterns)
- [Parameter inference rules](#parameter-inference-rules)
- [Path parameters](#path-parameters)
- [Query parameters](#query-parameters)
- [Header parameters](#header-parameters)
- [Request body parameters](#request-body-parameters)
- [Raw `Request` and `RequestContext` access](#raw-request-and-requestcontext-access)
- [Return-value handling](#return-value-handling)
- [Status codes](#status-codes)
- [The `attachToApp` extension method](#the-attachtoapp-extension-method)
- [Mounting under a prefix (versioning)](#mounting-under-a-prefix-versioning)
- [Multiple controllers](#multiple-controllers)
- [Common pitfalls](#common-pitfalls)

## Anatomy of a controller

A controller is any annotated class. It can have constructor
arguments (use them for dependency injection), instance state, and
any number of route methods.

```dart
import 'package:gisila_web/gisila_web.dart';

part 'users_controller.g.dart';

@Controller('/users')
class UsersController {
  UsersController(this._repo);
  final UserRepository _repo;

  @Get('/{id}')
  Future<User> get(String id) async => _repo.find(id);
}
```

Three constraints:

1. **Top-level class** - inner / private / sealed classes won't be
   discovered by the generator.
2. **`part 'foo.g.dart';`** - the generated extension lives in a part
   file that sits next to your source.
3. **Public methods** - the generator only inspects public instance
   methods that carry an HTTP-method annotation.

## The `@Controller` annotation

```dart
class Controller {
  const Controller([this.path = '']);
  final String path;
}
```

`path` is prepended to every method's route path. Both empty and
non-empty values are valid; trailing slashes are normalised:

| `@Controller`   | `@Get('/')`  | `@Get('/{id}')`   |
| --------------- | ------------ | ----------------- |
| `''`            | `/`          | `/{id}`           |
| `'/users'`      | `/users/`    | `/users/{id}`     |
| `'/api/v1/u'`   | `/api/v1/u/` | `/api/v1/u/{id}`  |

`@Controller` only affects routing - permission guards and named
middleware use their own annotations (see
[permissions.md](permissions.md) and [middleware.md](middleware.md)).

## HTTP method annotations

| Annotation                 | Verb     | Default success status |
| -------------------------- | -------- | ---------------------- |
| `@Get(path)`               | GET      | 200 OK                 |
| `@Post(path)`              | POST     | 201 Created            |
| `@Put(path)`               | PUT      | 200 OK                 |
| `@Patch(path)`             | PATCH    | 200 OK                 |
| `@Delete(path)`            | DELETE   | 204 No Content         |
| `@Head(path)`              | HEAD     | 200 OK                 |
| `@Options(path)`           | OPTIONS  | 204 No Content         |

Override the success status when needed:

```dart
@Post('/uploads', statusCode: 202)         // 202 Accepted
Future<UploadReceipt> upload(...) async => ...;
```

You can also override the response content type (rarely useful for
JSON APIs):

```dart
@Get('/feed.atom', contentType: 'application/atom+xml')
Future<Response> atomFeed() async => Response.ok(_buildAtom(),
    headers: {'content-type': 'application/atom+xml'});
```

## Path patterns

Paths use **OpenAPI-style braces** for placeholders: `/{name}`.
Under the hood they're translated to `shelf_router`'s `<name>`
syntax, so any naming rule that applies to `shelf_router` also
applies here:

* `{name}` - the placeholder name must be a valid Dart identifier.
* Mount points (`/api/{version}/posts/{id}`) work as expected.
* Wild-card / regex patterns are not exposed by the annotations.
  Use a raw `Request` parameter if you need them.

## Parameter inference rules

For every method parameter, the generator picks a source using this
ordered list:

1. **Explicit annotation** - `@Path`, `@Query`, `@Header`, `@Body`.
2. **`shelf.Request` parameter** - passed through untouched.
3. **`RequestContext` parameter** - receives the framework-managed
   context (principal, request id, scratch space).
4. **Name matches a `{placeholder}`** in the route path → **path
   parameter**.
5. **Primitive type** (`String`, `int`, `double`, `num`, `bool`,
   `DateTime`) → **query parameter**.
6. **Anything else** (custom class, `List<T>`, `Map<String, V>`) →
   **request body**. At most one body parameter is allowed.

Nullable types (`int?`, `String?`) become **optional** automatically
- both for query/header params (no error when missing) and for body
params (`null` accepted).

## Path parameters

A name match is enough; no annotation needed.

```dart
@Get('/posts/{slug}/comments/{id}')
Future<Comment> comment(String slug, int id) async => ...;
```

To use a different parameter name than the placeholder, annotate it
explicitly:

```dart
@Get('/posts/{slug}')
Future<Post> get(@Path(name: 'slug') String articleSlug) async => ...;
```

Path parameters are always **required** (missing them is a 404 from
the router, not a 400 from the parameter decoder).

## Query parameters

Any primitive parameter that doesn't match a placeholder is a query
parameter:

```dart
@Get('/')
Future<List<Post>> list({int? limit, int? offset, String? tag}) async => ...;
```

* `?limit=10&offset=0` → typed `int`s.
* Missing nullable parameters resolve to `null`.
* Missing non-nullable parameters return `400 Bad Request`.
* Invalid values (e.g. `?limit=abc` for `int`) also return `400`.

Use `@Query(name: 'q')` to expose a different external name:

```dart
@Get('/search')
Future<List<Post>> search(@Query(name: 'q') String? query) async => ...;
```

Booleans accept `true`/`false`, `1`/`0`, `yes`/`no` (case-insensitive).
`DateTime` accepts any ISO-8601 string.

## Header parameters

Headers are inferred from `@Header()` annotations only; there's no
implicit rule that turns a `String` parameter into a header.

```dart
@Get('/me')
Future<User> me(@Header(name: 'X-Tenant-Id') String? tenantId) async => ...;
```

Header lookup is case-insensitive (Shelf normalises headers to
lower-case internally).

## Request body parameters

The first non-primitive, non-path parameter becomes the request body:

```dart
@Post('/')
Future<User> create(CreateUser body) async => ...;
```

`POST`, `PUT`, and `PATCH` requests are decoded by a single
content-type-aware helper (`readBody`) that supports three flavours
out of the box:

| `Content-Type`                       | Decoded as                          |
| ------------------------------------ | ----------------------------------- |
| `application/json`                   | `Map` / `List` / primitive (JSON)   |
| `application/x-www-form-urlencoded`  | `FormData` (text-only)              |
| `multipart/form-data`                | `FormData` (text fields + files)    |

`FormData` *is* a `Map<String, Object>` (via `MapMixin`), so the
parameter-type → decoder dispatch is:

| Parameter type                                | Behaviour                                                                                              |
| --------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| `Map<String, dynamic>`                        | Works for all three content types. Files appear as `UploadedFile` values for multipart.                |
| `FormData`                                    | Works for urlencoded / multipart only; throws `400` on JSON.                                           |
| `UploadedFile`                                | Multipart-only convenience: reads `readFormBody(...).files[name]` using the parameter name as the key. |
| Class with `fromForm(Map<String, dynamic>)`   | Used for urlencoded / multipart bodies. Use this to coerce string-only form values into your types.    |
| Class with `fromJson(Map<String, dynamic>)`   | Used for JSON bodies (and form bodies when no `fromForm` factory exists).                              |
| Class with **both** `fromForm` and `fromJson` | Dispatched at runtime: `FormData` → `fromForm`, anything else → `fromJson`.                            |
| `List<T>` where `T` has `fromJson`            | JSON-only - element-wise hydration via `fromJson`.                                                     |
| `List<dynamic>` / `List<Map>`                 | JSON-only - decoded array passed through.                                                              |
| Anything else                                 | Raw decoded value from `readBody`.                                                                     |

Mark a body as optional via `@Body(required: false)` or by making the
parameter nullable:

```dart
@Patch('/{id}')
Future<User> update(String id, UpdateUser? body) async => ...;
```

### Form-urlencoded + JSON dual-shape models

When a class exposes both factories, the generator picks the right
one for the incoming request:

```dart
class LoginForm {
  LoginForm({required this.username, this.remember = false});

  factory LoginForm.fromJson(Map<String, dynamic> json) => LoginForm(
        username: json['username'] as String,
        remember: (json['remember'] as bool?) ?? false,
      );

  factory LoginForm.fromForm(Map<String, dynamic> form) => LoginForm(
        username: form['username'] as String,
        // Form values are always strings - coerce explicitly.
        remember: switch (form['remember']) {
          'true' || '1' || 'yes' || 'on' => true,
          _ => false,
        },
      );

  final String username;
  final bool remember;
}

@Post('/login')
Future<...> login(LoginForm body) async => ...;
```

The same endpoint now accepts:

```bash
curl -d '{"username":"a","remember":true}' -H 'content-type: application/json' /login
curl -d 'username=a&remember=on' -H 'content-type: application/x-www-form-urlencoded' /login
```

### Multipart uploads

Declare an `UploadedFile` parameter and the generator wires the file
extraction for you:

```dart
@Post('/{id}/avatar')
Future<Map<String, Object?>> uploadAvatar(String id, UploadedFile file) async {
  final bytes = await file.readAsBytes();
  return {'filename': file.name, 'size': bytes.length};
}
```

```bash
curl -F 'file=@avatar.png' http://localhost:8080/users/42/avatar
```

If the file is missing the framework returns a uniform `400`:

```json
{"error":{"status":400,"code":"bad_request","message":"Missing file \"file\" in multipart body."}}
```

For multi-file or mixed-field uploads, take the whole bag instead:

```dart
@Post('/import')
Future<Map<String, Object?>> import(FormData body) async {
  final csv = body.files['rows']!;
  final mode = body.fields['mode'] ?? 'append';
  // ...
}
```

### Rejecting other content types

The bundled `allowedContentTypesMiddleware()` returns `415 Unsupported
Media Type` for any `POST` / `PUT` / `PATCH` outside the whitelist:

```dart
final app = GisilaApp(config: AppConfig(...));
app.use(allowedContentTypesMiddleware()); // default: json + form + multipart
// or restrict further:
app.use(allowedContentTypesMiddleware(
  contentTypes: {'application/json'},
));
```

### Reading the body manually

You can always opt out of generation and decode by hand:

```dart
@Post('/avatar')
Future<Response> uploadAvatar(Request request) async {
  final body = await readBody(request);        // dispatches by Content-Type
  // or
  final form = await readFormBody(request);    // forms only
  final json = await readJsonBody(request);    // JSON only
  return Response.ok('{"ok":true}');
}
```

## Raw `Request` and `RequestContext` access

Two parameter types receive special treatment - they are *not*
treated as the body even if they appear in a method that already has
a real body parameter.

```dart
@Post('/')
@RequireAuth()
Future<User> create(
  Request request,            // raw shelf request
  RequestContext ctx,         // framework context
  CreateUser body,            // JSON body
) async {
  final ua = request.headers['user-agent'];
  ctx.extra['x-trace'] = 'created-${ctx.requestId}';
  return repo.createFor(ctx.principal!.id, body);
}
```

`RequestContext` carries:

| Field             | Type                  | When set                       |
| ----------------- | --------------------- | ------------------------------ |
| `requestId`       | `String`              | always (random or echoed)      |
| `request`         | `Request`             | always                         |
| `principal`       | `Principal?`          | after the authenticator runs   |
| `extra`           | `Map<String, Object?>`| scratch space for middleware   |

## Return-value handling

| Return type                  | Behaviour                                          |
| ---------------------------- | -------------------------------------------------- |
| `Response` / `Future<Response>` | Passed straight through (you control it).       |
| `void` / `Future<void>`         | Empty body, default status (e.g. 204 for DELETE). |
| `Map`, `List`, primitive, etc.  | JSON-encoded; `toJson()` is honoured recursively. |
| `Stream<List<int>>`             | Use a raw `Response` with that as the body.       |

The encoder walks `List` / `Map` and calls `toJson()` on nested
custom types. `DateTime` is serialised as ISO-8601.

## Status codes

The default success status comes from the annotation
(`@Post` → 201, `@Delete` → 204, others → 200). Override per route:

```dart
@Post('/', statusCode: 202)
Future<ProcessingReceipt> enqueue(Task body) async => ...;
```

If you return `Response` directly, **its** status code is used
verbatim. If you `throw` an `HttpException`, that exception's
`statusCode` wins (see [error-handling.md](error-handling.md)).

## The `attachToApp` extension method

Each `@Controller` class gets an extension method that you register
on the `GisilaApp`:

```dart
extension UsersControllerGisilaWeb on UsersController {
  void attachToApp(
    GisilaApp app,
    Router router, {
    String prefix = '',
  });
}
```

Pass it as a tear-off:

```dart
final users = UsersController(repo);
app.registerController(attacher: users.attachToApp);
```

The tear-off has exactly the `ControllerAttacher` typedef shape, so
the Dart analyser will tell you if your controller class is missing
its generated extension (i.e. you forgot to run `build_runner`).

## Mounting under a prefix (versioning)

`registerController` accepts a `prefix` that is concatenated *before*
the controller's own `@Controller(path)`:

```dart
app.registerController(
  attacher: UsersController(repo).attachToApp,
  prefix: '/api/v1',
);
```

The example controller with `@Controller('/users')` is now exposed
under `/api/v1/users/...`, and the same prefix appears in OpenAPI
paths if you later add a spec layer.

## Multiple controllers

Just register them - the underlying `Router` accepts any number of
routes, and each controller can carry its own permission guards.

```dart
app
  ..registerController(attacher: AuthController(...).attachToApp)
  ..registerController(attacher: UsersController(...).attachToApp,
                       prefix: '/api/v1')
  ..registerController(attacher: PostsController(...).attachToApp,
                       prefix: '/api/v1');
```

Route conflicts (two controllers registering the same method + path)
follow `shelf_router` semantics: the first registration wins. Keep
paths disjoint or use prefixes.

## Common pitfalls

* **"Could not classify parameter X"** - the generator gave up. You
  most likely have a body parameter on a method that already has
  one, or a custom-typed parameter that should be path/query/header.
  Annotate explicitly.
* **"params getter not defined for Request"** - you're missing the
  re-exported `package:gisila_web/gisila_web.dart` import in the
  controller file (or you imported `shelf` directly without
  `shelf_router`).
* **Old `.g.dart` file** - if you renamed or removed a route, re-run
  `dart run build_runner build --delete-conflicting-outputs`.
* **`fromJson` / `fromForm` not found** - the body decoder requires a
  public `factory ClassName.fromJson(Map<String, dynamic> json)` for
  JSON bodies, or `factory ClassName.fromForm(Map<String, dynamic>
  form)` for form-urlencoded / multipart bodies. Missing factories
  cause a `TypeError` → `400` at request time.
* **`UploadedFile` parameter on a JSON-only route** - `UploadedFile`
  requires the request to be `multipart/form-data`; sending JSON to
  such a route returns a `400` from `readFormBody`.
* **Returning the wrong type** - methods declared as `Future<void>`
  ignore any value you return; switch to a real type if you want
  the value JSON-encoded.
