# Testing

Controllers built with `gisila_web` are easy to test without booting
a real HTTP server. You can exercise the full pipeline - including
the authentication guard and any named middleware - against an
in-memory `Handler`, and assert on the resulting `Response` directly.

## Table of contents

- [Test layering](#test-layering)
- [Unit-testing the controller](#unit-testing-the-controller)
- [Integration test against the full pipeline](#integration-test-against-the-full-pipeline)
- [Testing the permission guard](#testing-the-permission-guard)
- [Mocking the `Authenticator`](#mocking-the-authenticator)
- [Mocking the `PermissionResolver`](#mocking-the-permissionresolver)
- [Asserting on log output](#asserting-on-log-output)
- [Testing custom middleware](#testing-custom-middleware)
- [End-to-end with a real HTTP server](#end-to-end-with-a-real-http-server)

## Test layering

A useful mental model:

| Layer                          | Tested with                                        |
| ------------------------------ | -------------------------------------------------- |
| Plain method on a controller   | Direct call - bypasses everything framework-y.     |
| Controller method via routing  | Build a `Handler` and call it with a `Request`.    |
| Controller + guards            | Same, plus configure an `Authenticator`.           |
| Full HTTP                      | `dart_test_tools` / `shelf_io.serve` on a free port. |

The first three layers run in-process at unit-test speed; reserve the
fourth for smoke tests.

## Unit-testing the controller

For methods that don't touch the request/response, just call them:

```dart
test('listUsers paginates', () async {
  final controller = UsersController();
  await controller.createUser(CreateUser(name: 'a', email: 'a@b.com'));
  await controller.createUser(CreateUser(name: 'b', email: 'b@b.com'));

  final all = await controller.listUsers();
  expect(all, hasLength(2));

  final paged = await controller.listUsers(limit: 1, offset: 1);
  expect(paged.single.name, 'b');
});
```

The generator does nothing surprising at this layer - your method is
still a plain Dart method.

## Integration test against the full pipeline

To exercise routing, body decoding, error mapping, and guards in one
go, build a `Handler` by hand:

```dart
import 'package:gisila_web/gisila_web.dart';
import 'package:test/test.dart';

import 'package:my_app/controllers/users_controller.dart';

Handler bootHandler({Authenticator? authenticator}) {
  final app = GisilaApp(
    config: AppConfig(
      logRequests: false,                                // quiet test output
      authenticator: authenticator ?? const NullAuthenticator(),
    ),
  );
  final router = Router();
  UsersController().attachToApp(app, router);

  return const Pipeline()
      .addMiddleware((inner) => (Request r) {
            final req = r.change(context: {...r.context, kAppKey: app});
            return inner(req);
          })
      .addHandler(router.call);
}
```

> The "inject app into context" middleware is the only piece you
> need outside of `GisilaApp.start()` - it's what
> `guardRequest` looks for. The full `GisilaApp.buildHandler()`
> includes more middleware (request id, access log, error mapper);
> if you want all of that, just call `buildHandler()` instead.

A typical test:

```dart
test('GET /users/me returns the principal', () async {
  final handler = bootHandler(
    authenticator: const StaticTokenAuthenticator({
      'good': Principal(id: 'u1', roles: {'reader'}),
    }),
  );

  final res = await handler(Request(
    'GET',
    Uri.parse('http://x/users/me'),
    headers: {'authorization': 'Bearer good'},
  ));

  expect(res.statusCode, 200);
  final body = jsonDecode(await res.readAsString()) as Map<String, Object?>;
  expect(body['id'], 'u1');
  expect(body['roles'], ['reader']);
});
```

## Testing the permission guard

Mix `@Permissions` / `@AnyPermission` / `@Roles` into the test by
giving the principal the right (or wrong) scopes:

```dart
test('POST /users/ requires users:write', () async {
  final handler = bootHandler(
    authenticator: const StaticTokenAuthenticator({
      'reader':  Principal(id: 'r', permissions: {'users:read'}),
      'writer':  Principal(id: 'w', permissions: {'users:write'}),
    }),
  );

  Future<int> post(String token) async {
    final res = await handler(Request(
      'POST',
      Uri.parse('http://x/users/'),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $token',
      },
      body: '{"name":"x","email":"x@y.com"}',
    ));
    return res.statusCode;
  }

  expect(await post('reader'), 403);    // missing users:write
  expect(await post('writer'), 201);    // ok
});
```

## Mocking the `Authenticator`

Implement the interface for one-off test setups:

```dart
class _StaticPrincipalAuthenticator extends Authenticator {
  const _StaticPrincipalAuthenticator(this.principal);
  final Principal? principal;

  @override
  Future<Principal?> authenticate(Request request) async => principal;
}

test('skips auth when token returns null', () async {
  final handler = bootHandler(
    authenticator: const _StaticPrincipalAuthenticator(null),
  );
  final res = await handler(Request('GET', Uri.parse('http://x/users/me')));
  expect(res.statusCode, 401);
});
```

For "what does my JWT authenticator do with an expired token?" tests,
construct the authenticator directly without booting the framework:

```dart
test('rejects expired JWT', () async {
  final auth = JwtAuthenticator('test-secret');
  final token = JWT({'sub': 'u1'},
      expiresAt: DateTime.now().subtract(const Duration(hours: 1)))
      .sign(SecretKey('test-secret'));

  expect(
    () => auth.authenticate(Request(
      'GET', Uri.parse('http://x/'),
      headers: {'authorization': 'Bearer $token'},
    )),
    throwsA(isA<HttpException>().having((e) => e.statusCode, 'status', 401)),
  );
});
```

## Mocking the `PermissionResolver`

```dart
class _AllowList extends PermissionResolver {
  _AllowList(this.allowed);
  final Set<String> allowed;
  @override Future<bool> hasPermission(Principal p, String perm) async =>
      allowed.contains(perm);
  @override Future<bool> hasRole(Principal p, String role) async =>
      p.roles.contains(role);
}

final app = GisilaApp(
  config: AppConfig(
    authenticator: const StaticTokenAuthenticator(
        {'t': Principal(id: 'u')}),
    permissionResolver: _AllowList({'users:read'}),
  ),
);
```

Useful when your real resolver hits a database that you don't want
to spin up.

## Asserting on log output

`ConsoleLogger` accepts injectable sinks - capture the lines instead
of letting them hit stdout:

```dart
test('logs the access line', () async {
  final lines = <String>[];
  final logger = ConsoleLogger(
    level: LogLevel.info,
    format: LogFormat.json,
    stdoutSink: lines.add,
    stderrSink: lines.add,
  );
  final app = GisilaApp(
    config: AppConfig(logger: logger, logRequests: true),
  );
  app.registerController(attacher: UsersController().attachToApp);

  final handler = app.buildHandler();
  await handler(Request('GET', Uri.parse('http://x/users/me')));

  final record = jsonDecode(lines.last) as Map<String, Object?>;
  expect(record['method'], 'GET');
  expect(record['path'], '/users/me');
  expect(record['status'], 401);
});
```

For pure unit tests against the `Logger` interface itself, see the
`test/logger_test.dart` file in this repo.

## Testing custom middleware

Middleware is just a function - no framework needed:

```dart
test('idempotencyMiddleware replays cached responses', () async {
  final cache = <String, String>{};
  final mw = ((Handler inner) => (Request request) async {
    final key = request.headers['idempotency-key'];
    if (key != null && cache.containsKey(key)) {
      return Response(200, body: cache[key]);
    }
    final res = await inner(request);
    final body = await res.readAsString();
    if (key != null) cache[key] = body;
    return res.change(body: body);
  });

  final handler = mw((req) async => Response.ok(DateTime.now().toIso8601String()));

  final r1 = await handler(Request('POST', Uri.parse('http://x/x'),
      headers: {'idempotency-key': 'abc'}));
  final r2 = await handler(Request('POST', Uri.parse('http://x/x'),
      headers: {'idempotency-key': 'abc'}));

  expect(await r1.readAsString(), await r2.readAsString());
});
```

For middleware that depends on `RequestContext`, set it up by hand:

```dart
final app = GisilaApp(config: AppConfig(logRequests: false));
final ctx = RequestContext(requestId: 't', request: ...,
    principal: const Principal(id: 'u1', permissions: {'all'}));
final request = Request('GET', Uri.parse('http://x/'),
    context: {kAppKey: app, kContextKey: ctx});
```

## End-to-end with a real HTTP server

Sometimes you need to assert against a real socket (verifying TLS,
chunked transfer encoding, etc.). Spin up a server on port `0`
(any available port) inside the test:

```dart
test('full http round-trip', () async {
  final app = GisilaApp(config: AppConfig(logRequests: false));
  app.registerController(attacher: UsersController().attachToApp);

  final server = await app.start(host: '127.0.0.1', port: 0);
  addTearDown(() async => server.close(force: true));

  final res = await HttpClient()
      .getUrl(Uri.parse('http://127.0.0.1:${server.port}/users/ping'));
  final response = await res.close();

  expect(response.statusCode, 200);
});
```

`GisilaApp.start(port: 0)` lets the OS pick a free port and returns
the live `HttpServer`; `server.port` exposes the actual port.
Cleaning up with `addTearDown` keeps your test runs independent.
