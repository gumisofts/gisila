# Cookbook

Short, copy-paste-friendly recipes for common needs. Most are 10-20
lines on top of what `gisila_web` ships with.

## Table of contents

- [Pagination helpers](#pagination-helpers)
- [Versioned APIs](#versioned-apis)
- [API key + JWT side-by-side](#api-key--jwt-side-by-side)
- [Multi-tenant routing](#multi-tenant-routing)
- [Idempotency keys](#idempotency-keys)
- [File uploads](#file-uploads)
- [Server-Sent Events](#server-sent-events)
- [Health and readiness probes](#health-and-readiness-probes)
- [Graceful shutdown](#graceful-shutdown)
- [Scheduled background jobs](#scheduled-background-jobs)
- [Metrics endpoint](#metrics-endpoint)
- [OpenTelemetry tracing](#opentelemetry-tracing)
- [OpenAPI / Swagger (with `shelf_openapi`)](#openapi--swagger-with-shelf_openapi)

## Pagination helpers

Centralise the query-parsing logic:

```dart
class PageQuery {
  PageQuery(this.limit, this.offset);

  factory PageQuery.fromQuery(int? limit, int? offset) =>
      PageQuery((limit ?? 25).clamp(1, 100), (offset ?? 0).clamp(0, 100000));

  final int limit;
  final int offset;
}

@Get('/')
@Permissions({'posts:read'})
Future<Map<String, Object?>> list({int? limit, int? offset}) async {
  final q = PageQuery.fromQuery(limit, offset);
  final rows = await repo.posts.where(...).limit(q.limit).offset(q.offset).get();
  final total = await repo.posts.where(...).count();
  return {
    'items': rows,
    'limit': q.limit,
    'offset': q.offset,
    'total': total,
  };
}
```

## Versioned APIs

Use the `prefix` argument to `registerController`:

```dart
app
  ..registerController(attacher: UsersV1().attachToApp, prefix: '/api/v1')
  ..registerController(attacher: UsersV2().attachToApp, prefix: '/api/v2');
```

V1 and V2 can be entirely different classes with different paths,
parameters, and DTOs. No magic, no shared base class required.

## API key + JWT side-by-side

A composite authenticator tries each strategy in turn:

```dart
class MultiAuthenticator extends Authenticator {
  const MultiAuthenticator(this.strategies);
  final List<Authenticator> strategies;

  @override
  Future<Principal?> authenticate(Request request) async {
    for (final s in strategies) {
      final p = await s.authenticate(request);
      if (p != null) return p;
    }
    return null;
  }
}

final app = GisilaApp(
  config: AppConfig(
    authenticator: MultiAuthenticator([
      JwtAuthenticator(env.jwtSecret),
      ApiKeyAuthenticator(db),
    ]),
  ),
);
```

Throwing inside any one strategy short-circuits with a `401`.

## Multi-tenant routing

If your tenant id lives in a header:

```dart
Middleware tenantMiddleware() {
  return (inner) => (request) async {
    final tenant = request.headers['x-tenant-id'];
    if (tenant == null) throw BadRequest('Missing X-Tenant-Id');
    final ctx = RequestContext.maybeOf(request)!;
    ctx.extra['tenantId'] = tenant;
    return inner(request);
  };
}

app.use(tenantMiddleware());
```

If it's in the path:

```dart
@Controller('/tenants/{tenantId}')
@RequireAuth()
class TenantScopedController {
  @Get('/users')
  Future<List<User>> users(String tenantId) async =>
      repo.usersFor(tenantId);
}
```

Either way, `@Permissions({'users:read'})` still gates the route -
plug your `PermissionResolver` into the tenant model to handle
per-tenant scopes.

## Idempotency keys

```dart
Middleware idempotencyMiddleware(KvStore store) {
  return (inner) => (request) async {
    final key = request.headers['idempotency-key'];
    if (key == null || request.method == 'GET') return inner(request);

    final cached = await store.get('idem:$key');
    if (cached != null) {
      return Response(200, body: cached,
          headers: {'content-type': 'application/json'});
    }
    final response = await inner(request);
    if (response.statusCode < 500) {
      final body = await response.readAsString();
      await store.setex('idem:$key', 3600, body);
      return response.change(body: body);
    }
    return response;
  };
}

app.registerNamedMiddleware('idempotency',
    idempotencyMiddleware(redis));

@Post('/payments')
@Permissions({'payments:write'})
@UseMiddleware('idempotency')
Future<Payment> charge(ChargeRequest body) async => paymentsService.charge(body);
```

## File uploads

The framework ships with a built-in `multipart/form-data` parser, so
the simplest pattern is just to declare an `UploadedFile` parameter
and let the generator wire the extraction:

```dart
@Post('/avatars/{id}')
@Permissions({'profile:write'})
Future<Map<String, Object?>> uploadAvatar(
  String id,
  UploadedFile file,
) async {
  final bytes = await file.readAsBytes();
  if (bytes.length > 2 * 1024 * 1024) {
    throw BadRequest('Avatar must be <= 2 MiB', code: 'avatar_too_large');
  }
  final url = await storage.put(
    'avatars/$id',
    bytes,
    contentType: file.contentType.mimeType,
  );
  return {'url': url, 'filename': file.name, 'size': bytes.length};
}
```

```bash
curl -F 'file=@me.png' http://localhost:8080/avatars/42
```

If you need multiple files or mixed text + file fields, take the
whole bag with a `FormData` parameter:

```dart
@Post('/imports')
@Permissions({'data:write'})
Future<Map<String, Object?>> importCsv(FormData body) async {
  final mode = body.fields['mode'] ?? 'append';
  final csv = body.files['rows']
      ?? (throw BadRequest('Missing "rows" file'));
  final rows = await csv.readAsBytes();
  return repo.importRows(rows, mode: mode);
}
```

For streaming uploads (>10 MiB, no in-memory buffering) use
`file.openRead()` instead of `readAsBytes()`:

```dart
@Post('/blobs')
Future<Map<String, Object?>> blob(UploadedFile file) async {
  await storage.streamTo('blobs/${file.name}', file.openRead());
  return {'ok': true};
}
```

For low-level access to a raw, non-multipart body (e.g. a direct PUT
with `application/octet-stream`), drop down to a `Request` parameter:

```dart
@Put('/blobs/{id}')
Future<Response> putBlob(String id, Request request) async {
  final bytes = await request.read().fold<List<int>>(
      <int>[], (acc, chunk) => acc..addAll(chunk));
  await storage.put('blobs/$id', bytes,
      contentType: request.headers['content-type']
          ?? 'application/octet-stream');
  return Response.ok('{"ok":true}',
      headers: {'content-type': 'application/json'});
}
```

## Server-Sent Events

```dart
@Get('/events')
@RequireAuth()
Future<Response> stream(RequestContext ctx) async {
  final controller = StreamController<List<int>>();
  Timer.periodic(const Duration(seconds: 1), (t) {
    if (controller.isClosed) return t.cancel();
    controller.add(utf8.encode('data: ${DateTime.now().toIso8601String()}\n\n'));
  });
  return Response.ok(controller.stream, headers: {
    'content-type': 'text/event-stream',
    'cache-control': 'no-cache',
    'connection': 'keep-alive',
  });
}
```

Remember to close the stream when the request is cancelled - hook
into `request.context['shelf.io.connection']?.onDone`.

## Health and readiness probes

```dart
@Controller('/health')
class HealthController {
  HealthController(this._db);
  final DbContext _db;

  @Get('/live') @Public()
  Future<Map<String, Object?>> live() async => {'status': 'ok'};

  @Get('/ready') @Public()
  Future<Map<String, Object?>> ready() async {
    try {
      await _db.execute('SELECT 1');
      return {'status': 'ok'};
    } catch (e) {
      throw HttpException(503, 'Database unreachable', code: 'db_down');
    }
  }
}
```

## Graceful shutdown

```dart
final app = GisilaApp(config: AppConfig(...));
app.registerController(attacher: UsersController().attachToApp);

final server = await app.start(host: '0.0.0.0', port: 8080);

ProcessSignal.sigterm.watch().listen((_) async {
  app.config.logger.info('SIGTERM received, draining...');
  await app.stop(force: false);     // closes listening socket, drains
  exit(0);
});
```

`app.stop()` calls `server.close()` under the hood; pass
`force: true` to drop in-flight requests.

## Scheduled background jobs

Run an async loop alongside the server. The same `Logger`,
`Authenticator`, and config are reachable:

```dart
Future<void> runJobs(GisilaApp app) async {
  while (true) {
    try {
      final job = await jobs.popExpired();
      if (job == null) {
        await Future.delayed(const Duration(seconds: 5));
        continue;
      }
      app.config.logger.info('running job', fields: {'jobId': job.id});
      await job.run();
    } catch (e, st) {
      app.config.logger.error('job failed', error: e, stackTrace: st);
    }
  }
}

await Future.wait([
  app.start(host: '0.0.0.0', port: 8080),
  runJobs(app),
]);
```

## Metrics endpoint

If you collect Prometheus metrics with a registry, expose them:

```dart
@Controller('/metrics')
class MetricsController {
  MetricsController(this._registry);
  final CollectorRegistry _registry;

  @Get('/') @Public()
  Future<Response> scrape() async {
    final body = await _registry.collectAndExport();
    return Response.ok(body, headers: {
      'content-type': 'text/plain; version=0.0.4',
    });
  }
}
```

## OpenTelemetry tracing

Use a global middleware that spans every request:

```dart
Middleware tracingMiddleware(Tracer tracer) {
  return (inner) => (request) async {
    final span = tracer.startSpan(
      '${request.method} ${request.url.path}',
      attributes: {
        'http.method': request.method,
        'http.target': request.url.path,
      },
    );
    try {
      final response = await inner(request);
      span.setAttribute('http.status_code', response.statusCode);
      return response;
    } catch (e, st) {
      span.recordException(e, stackTrace: st);
      rethrow;
    } finally {
      span.end();
    }
  };
}

app.use(tracingMiddleware(otel.tracer('gisila_web')));
```

## OpenAPI / Swagger (with `shelf_openapi`)

`gisila_web` and `shelf_openapi` are independent packages. If you
also want auto-generated OpenAPI docs, add `shelf_openapi` to the
same controller class and run both generators:

```dart
import 'package:gisila_web/gisila_web.dart' hide Body, Path, Query, Header;
import 'package:shelf_openapi/shelf_openapi.dart' as openapi;

part 'users_controller.g.dart';                    // gisila_web
part 'users_controller.openapi.g.dart';            // shelf_openapi (configure separately)
```

> Because both packages provide annotations with overlapping names
> (`Body`, `Path`, `Query`, `Header`), import one of them with
> `hide` or `as` to disambiguate.

Then in `main`:

```dart
final spec = openapi.OpenApiSpec(info: openapi.ApiInfo(...));
final router = Router();

users.attachToApp(app, router);            // wires routes + guards
users.attachOpenApi(spec, router);          // adds OpenAPI metadata

router.mount('/', openapi.docsHandler(spec));   // /openapi.json, /docs
```

This isn't formalised yet - we expect to ship a small bridge package
later that emits both extensions from a single generator pass.
