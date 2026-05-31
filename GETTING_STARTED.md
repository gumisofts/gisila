# Getting started with gisila

A step-by-step tutorial that takes you from an empty directory to a
running HTTP API with annotation-driven routing, typed input forms,
request-scoped services, declarative permissions, per-route
configuration, and structured JSON error responses. By the end you'll
have a small protected "todos" service backed by gisila.

> **Time required:** 10 minutes.
> **You will need:** Dart SDK 3.3+ and `curl`.
> **You will write:** one controller, one form, one service, and a
> bootstrap file.

If you just want the reference, see [README.md](README.md) and the
[docs/](docs/) folder. This document is the tutorial; it deliberately
repeats things that are also documented there in shorter form.

> **0.2.0 note (BREAKING):** the package is now imported as
> `package:gisila/gisila.dart` (formerly `gisila`). The legacy
> `form()` map helper, the `__inner(Request)` generated handler
> closure, and any user-land `handleRequest(...)` wrapper are gone.
> Inputs are typed [Form] subclasses; business logic lives in
> request-scoped [Service] subclasses; per-route configuration goes
> into `RouteConfig`. See the [README](README.md) for the new
> patterns and the [CHANGELOG](CHANGELOG.md) for the migration
> guide.

---

## Table of contents

1. [Prerequisites](#1-prerequisites)
2. [Create a new Dart project](#2-create-a-new-dart-project)
3. [Add gisila as a dependency](#3-add-gisila-as-a-dependency)
4. [Write your first controller](#4-write-your-first-controller)
5. [Generate the routing code](#5-generate-the-routing-code)
6. [Boot the server](#6-boot-the-server)
7. [Make some requests](#7-make-some-requests)
8. [Add a request body](#8-add-a-request-body)
9. [Protect a route with permissions](#9-protect-a-route-with-permissions)
10. [Plug in real authentication](#10-plug-in-real-authentication)
11. [Turn on JSON logging](#11-turn-on-json-logging)
12. [Add CORS, rate-limiting and a request timeout](#12-add-cors-rate-limiting-and-a-request-timeout)
13. [Return typed errors](#13-return-typed-errors)
14. [Test your controller](#14-test-your-controller)
15. [Project layout recap](#15-project-layout-recap)
16. [Where to go next](#16-where-to-go-next)

---

## 1. Prerequisites

Verify your toolchain:

```bash
dart --version          # >= 3.3.0
curl --version          # any recent version
```

You don't need a database, Docker, or any external service for this
tutorial.

---

## 2. Create a new Dart project

```bash
dart create -t console todo_api
cd todo_api
```

You now have:

```
todo_api/
├── analysis_options.yaml
├── bin/todo_api.dart          # entry point we'll edit later
├── lib/                       # we'll add controllers here
├── pubspec.yaml
└── test/
```

---

## 3. Add gisila as a dependency

If you've cloned the `gisila_tools` monorepo locally, point at the
sibling package directly:

```yaml
# pubspec.yaml
name: todo_api
description: A small protected API powered by gisila.
publish_to: none

environment:
  sdk: ^3.3.0

dependencies:
  gisila:
    path: ../gisila

dev_dependencies:
  build_runner: ^2.5.0
  test: ^1.24.0
  lints: ^3.0.0
```

Then:

```bash
dart pub get
```

> A single `package:gisila/gisila.dart` import re-exports everything
> you need from `shelf`, `shelf_router`, the framework runtime, and
> the annotation set. You will rarely need to import `shelf` directly.

---

## 4. Write your first controller

Create `lib/controllers/todos_controller.dart`:

```dart
import 'package:gisila/gisila.dart';

part 'todos_controller.g.dart';                  // <-- required

@Controller('/todos')
class TodosController {
  TodosController();

  final Map<String, String> _store = <String, String>{};

  @Get('/ping')
  @Public()
  Future<Map<String, Object?>> ping() async =>
      <String, Object?>{'status': 'ok'};

  @Get('/{id}')
  Future<Map<String, Object?>> get(String id) async {
    final value = _store[id];
    if (value == null) throw NotFound('Todo "$id" not found');
    return <String, Object?>{'id': id, 'text': value};
  }

  @Get('/')
  Future<List<Map<String, Object?>>> list() async => _store.entries
      .map((e) => <String, Object?>{'id': e.key, 'text': e.value})
      .toList();
}
```

Three things to notice:

* `@Controller('/todos')` declares the URL prefix for every route in
  the class.
* `@Get('/{id}')` carries the HTTP method and route path. The `id`
  parameter is automatically bound to the `{id}` placeholder.
* `throw NotFound('...')` becomes a uniform JSON `404` response - we'll
  cover the full exception hierarchy in step 13.

---

## 5. Generate the routing code

The framework reads your annotations at *build time* and emits a
small extension method on each controller. The "part of" line you
added is what makes that possible.

Run the generator:

```bash
dart run build_runner build --delete-conflicting-outputs
```

You should now have `lib/controllers/todos_controller.g.dart`. Open it
if you're curious - it's plain Dart and very easy to read.

> Re-run `build_runner build` whenever you change an annotation, a
> route path, or a parameter signature. While developing, prefer
> `dart run build_runner watch` to keep the output in sync.

---

## 6. Boot the server

Edit `bin/todo_api.dart`:

```dart
import 'package:gisila/gisila.dart';
import 'package:todo_api/controllers/todos_controller.dart';

Future<void> main() async {
  final app = GisilaApp(
    config: AppConfig(
      logLevel: LogLevel.info,
      logFormat: LogFormat.text,
    ),
  );

  app.registerController(attacher: TodosController().attachToApp);

  await app.start(host: '0.0.0.0', port: 8080);
}
```

That is the entire bootstrap. Start it:

```bash
dart run bin/todo_api.dart
# 2026-05-22T14:00:00Z [INFO ] gisila listening on http://0.0.0.0:8080 ...
```

Leave it running in this terminal; open a second one for the requests
below.

---

## 7. Make some requests

```bash
curl -s http://localhost:8080/todos/ping
# {"status":"ok"}

curl -s http://localhost:8080/todos/
# []

curl -i http://localhost:8080/todos/missing
# HTTP/1.1 404 Not Found
# {"error":{"status":404,"message":"Todo \"missing\" not found","code":"not_found"}}
```

You also get framework-supplied response headers for free:

```
x-request-id: f1qsK3Bz...
server: gisila/0.1.0
x-powered-by: gisila
content-type: application/json; charset=utf-8
```

And the server console prints one log line per request:

```
2026-05-22T14:01:00Z [INFO ] req=f1qsK3Bz GET /todos/ping -> 200 (1ms) ...
```

---

## 8. Add a request body via a typed Form

Forms in gisila are typed: you declare a `Form` subclass with one
`FormField` per expected request input, and the framework hands your
controller a fully populated typed instance. Only declared fields are
read; values are already parsed (never raw strings); validation errors
become a structured `400`.

Add a form class at the bottom of `todos_controller.dart` (or in its
own `lib/forms/todo_forms.dart` file):

```dart
class CreateTodoForm extends Form {
  final text = StringField(
    name: 'text',
    required: true,
    minLength: 1,
    maxLength: 280,
  );

  @override
  List<FormField<Object?>> collectFields() => [text];
}
```

Then a route. Note the controller method *takes the form as a typed
parameter* - the framework binds the request body for you, no manual
`form(...)`, no `request.readAsString()`, no casts:

```dart
  @Post('/')
  Future<Map<String, Object?>> create(CreateTodoForm body) async {
    final id = (_store.length + 1).toString();
    _store[id] = body.text.value!;     // already parsed and validated
    return <String, Object?>{'id': id, 'text': body.text.value};
  }
```

Re-run the generator and the server:

```bash
dart run build_runner build --delete-conflicting-outputs
# restart the server
dart run bin/todo_api.dart
```

Try it:

```bash
curl -s -X POST -H 'content-type: application/json' \
     -d '{"text":"buy milk"}' http://localhost:8080/todos/
# {"id":"1","text":"buy milk"}

# Missing field:
curl -s -X POST -H 'content-type: application/json' \
     -d '{}' http://localhost:8080/todos/
# {"error":{"status":400,"code":"validation_failed",
#   "message":"Invalid form data",
#   "details":{"text":"This field is required"}}}

# Validation failure (too long):
curl -s -X POST -H 'content-type: application/json' \
     -d '{"text":"...(over 280 chars)..."}' http://localhost:8080/todos/
# {"error":{"status":400,"code":"validation_failed",
#   "message":"Invalid form data",
#   "details":{"text":"Must be at most 280 characters"}}}
```

The same `CreateTodoForm` also binds `application/x-www-form-urlencoded`
and `multipart/form-data` bodies. No `fromJson` / `fromForm` factories
needed - the field types know how to parse themselves.

---

## 9. Protect a route with permissions

Annotate the create route:

```dart
  @Post('/')
  @Permissions({'todos:write'})
  Future<Map<String, Object?>> create(CreateTodo body) async {
    ...
  }
```

Regenerate and restart:

```bash
dart run build_runner build --delete-conflicting-outputs
dart run bin/todo_api.dart
```

```bash
curl -i -X POST -H 'content-type: application/json' \
     -d '{"text":"x"}' http://localhost:8080/todos/
# HTTP/1.1 401 Unauthorized
# {"error":{"status":401,"message":"Authentication required","code":"unauthorized"}}
```

Without an `Authenticator` configured the framework rejects every
guarded route. Let's wire one up.

---

## 10. Plug in real authentication

For now, use the bundled `StaticTokenAuthenticator` (great for tests;
swap for JWT later - see [docs/authentication.md](docs/authentication.md)).

Update `bin/todo_api.dart`:

```dart
final app = GisilaApp(
  config: AppConfig(
    logLevel: LogLevel.info,
    authenticator: const StaticTokenAuthenticator({
      'writer-token': Principal(
        id: 'writer',
        permissions: {'todos:write'},
      ),
      'reader-token': Principal(id: 'reader'),
    }),
  ),
);
```

Restart and:

```bash
curl -i -X POST -H 'Authorization: Bearer reader-token' \
     -H 'content-type: application/json' -d '{"text":"x"}' \
     http://localhost:8080/todos/
# HTTP/1.1 403 Forbidden
# {"error":{"status":403,"message":"Missing permission \"todos:write\"",...}}

curl -i -X POST -H 'Authorization: Bearer writer-token' \
     -H 'content-type: application/json' -d '{"text":"x"}' \
     http://localhost:8080/todos/
# HTTP/1.1 201 Created
# {"id":"1","text":"x"}
```

You now have full request → authenticate → authorise → handler flow,
all driven by annotations.

---

## 11. Turn on JSON logging

Switch the log format and add request bodies:

```dart
config: AppConfig(
  logLevel: LogLevel.info,
  logFormat: LogFormat.json,
  logRequestBody: true,
  authenticator: ...,
),
```

Restart and call any endpoint; the server now emits parseable records:

```json
{"ts":"2026-05-22T14:10Z","level":"info",
 "msg":"POST /todos/ -> 201 (3ms)",
 "requestId":"...","principalId":"writer",
 "method":"POST","path":"/todos/","status":201,"duration_ms":3,
 "remote":"127.0.0.1:55230",
 "requestBody":"{\"text\":\"x\"}"}
```

These line up with ELK, Loki, Datadog, etc. with zero extra work.

See [docs/logging.md](docs/logging.md) for custom loggers and
field redaction.

---

## 12. Add CORS, rate-limiting and a request timeout

Three more flags on `AppConfig`:

```dart
config: AppConfig(
  logLevel: LogLevel.info,
  authenticator: ...,
  cors: const CorsConfig(
    allowedOrigins: {'https://app.example.com'},
    allowCredentials: true,
  ),
  rateLimit: const RateLimitConfig(requestsPerMinute: 60),
  requestTimeout: const Duration(seconds: 10),
  maxRequestBodyBytes: 1024 * 1024,        // 1 MiB
),
```

* CORS pre-flight requests (`OPTIONS`) are answered automatically.
* The rate-limiter is in-process and per-remote-IP.
* The timeout aborts any request that hasn't completed in time and
  returns `504 Gateway Timeout`.

See [docs/middleware.md](docs/middleware.md) for the full middleware
catalogue and how to write your own.

---

## 13. Return typed errors

Don't write `Response.notFound('...')` by hand - throw the matching
exception and the framework renders it consistently:

| Exception                 | HTTP |
| ------------------------- | ---- |
| `BadRequest`              | 400  |
| `Unauthorized`            | 401  |
| `Forbidden`               | 403  |
| `NotFound`                | 404  |
| `Conflict`                | 409  |
| `TooManyRequests`         | 429  |
| `InternalServerError`     | 500  |
| any other `HttpException` | its `statusCode` |
| anything else             | 500 (also logged) |

Each renders as:

```json
{
  "error": {
    "status": 404,
    "code": "not_found",
    "message": "Todo \"42\" not found"
  }
}
```

You can attach a machine-readable `code` and structured `details`:

```dart
throw Conflict(
  'Email already exists',
  code: 'duplicate_email',
  details: {'email': body.email},
);
```

See [docs/error-handling.md](docs/error-handling.md) for custom
exception subclasses and the global `errorHandler` hook.

---

## 14. Test your controller

You don't need to spin up an HTTP server to test a controller. The
generated `attachToApp` method takes any `Router`; combine it with
shelf's `Pipeline`:

```dart
// test/todos_controller_test.dart
import 'dart:convert';

import 'package:gisila/gisila.dart';
import 'package:todo_api/controllers/todos_controller.dart';
import 'package:test/test.dart';

void main() {
  late Handler handler;

  setUp(() {
    final app = GisilaApp(
      config: AppConfig(
        logRequests: false,
        authenticator: const StaticTokenAuthenticator({
          'good': Principal(id: 'u', permissions: {'todos:write'}),
        }),
      ),
    );
    final router = Router();
    TodosController().attachToApp(app, router);

    handler = const Pipeline()
        .addMiddleware((inner) => (Request r) {
              final req = r.change(context: {...r.context, kAppKey: app});
              return inner(req);
            })
        .addHandler(router.call);
  });

  test('POST /todos/ requires permission', () async {
    final res = await handler(Request(
      'POST',
      Uri.parse('http://x/todos/'),
      headers: {'content-type': 'application/json'},
      body: '{"text":"hi"}',
    ));
    expect(res.statusCode, 401);
  });

  test('POST /todos/ with token succeeds', () async {
    final res = await handler(Request(
      'POST',
      Uri.parse('http://x/todos/'),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer good',
      },
      body: '{"text":"hi"}',
    ));
    expect(res.statusCode, 201);
    final body = jsonDecode(await res.readAsString()) as Map;
    expect(body['text'], 'hi');
  });
}
```

Run it:

```bash
dart test
```

See [docs/testing.md](docs/testing.md) for more patterns (mocking the
authenticator, asserting on log output, etc.).

---

## 15. Project layout recap

```
todo_api/
├── bin/
│   └── todo_api.dart                       # bootstrap (GisilaApp + start)
├── lib/
│   └── controllers/
│       ├── todos_controller.dart            # hand-written
│       └── todos_controller.g.dart          # generated
├── test/
│   └── todos_controller_test.dart
├── pubspec.yaml
└── analysis_options.yaml
```

A larger project simply has more controllers; you keep them small and
register each one on `GisilaApp.registerController`. The bootstrap
file rarely needs to grow.

---

## 16. Where to go next

* **[docs/controllers-and-routing.md](docs/controllers-and-routing.md)**
  - every annotation, parameter inference rules, custom status codes.
* **[docs/permissions.md](docs/permissions.md)** - permission/role
  guards, precedence, escape hatches.
* **[docs/authentication.md](docs/authentication.md)** - JWT
  authenticator recipe, custom permission resolvers.
* **[docs/middleware.md](docs/middleware.md)** - the bundled
  middleware catalogue plus how to write and register your own.
* **[docs/logging.md](docs/logging.md)** - custom log sinks (file,
  syslog, OTLP), redaction, levels per route.
* **[docs/configuration.md](docs/configuration.md)** - every
  `AppConfig` knob with defaults and trade-offs.
* **[docs/error-handling.md](docs/error-handling.md)** - exception
  hierarchy, custom `errorHandler`, debug-mode stack traces.
* **[docs/testing.md](docs/testing.md)** - testing controllers,
  middleware, and guards in isolation.
* **[docs/cookbook.md](docs/cookbook.md)** - copy-paste recipes:
  pagination, file uploads, server-sent events, OpenTelemetry,
  scheduled jobs.
