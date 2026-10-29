# Cookbook

Short, copy-paste-friendly recipes for common needs. Most are 10-20
lines on top of what `gisila` ships with.

## Table of contents

- [Pagination helpers](#pagination-helpers)
- [Versioned APIs](#versioned-apis)
- [API key + JWT side-by-side](#api-key--jwt-side-by-side)
- [Multi-tenant routing](#multi-tenant-routing)
- [Idempotency keys](#idempotency-keys)
- [File uploads](#file-uploads)
- [Server-Sent Events](#server-sent-events)
- [Static files and single-page apps](#static-files-and-single-page-apps)
- [Health and readiness probes](#health-and-readiness-probes)
- [Graceful shutdown](#graceful-shutdown)
- [Scheduled background jobs](#scheduled-background-jobs)
- [Metrics endpoint](#metrics-endpoint)
- [OpenTelemetry tracing](#opentelemetry-tracing)
- [OpenAPI / Swagger (with `shelf_openapi`)](#openapi--swagger-with-shelf_openapi)

## Pagination helpers

Declare the query parameters on the handler (so they're bound and show up
in the API docs), then let `PageParams` validate them and `Page` shape
the response:

```dart
@Get('/')
@Permissions({'posts:read'})
Future<Page<Post>> list({int? limit, int? offset}) async {
  final page = PageParams(limit: limit, offset: offset); // 25 by default, 100 at most
  final rows = await posts.list(limit: page.limit, offset: page.offset);
  return Page(rows, params: page, total: await posts.count());
}
```

```json
{"items": [...], "page": {"limit": 25, "offset": 50, "total": 240, "has_more": true}}
```

For large or fast-changing tables, page by cursor (keyset pagination)
instead of offset:

```dart
@Get('/feed')
Future<Page<Post>> feed({int? limit, String? cursor}) async {
  final page = PageParams(limit: limit, cursor: cursor);
  final after = cursor == null ? null : Cursor.decode(cursor); // 400 if malformed
  final rows = await posts.after(id: after?['id'] as int?, limit: page.limit + 1);
  final more = rows.length > page.limit;
  final items = rows.take(page.limit).toList();
  return Page(items,
      params: page,
      nextCursor: more ? Cursor.encode({'id': items.last.id}) : null);
}
```

A `limit` above the maximum is cut down; a negative offset or zero limit
is a `400`. Cursors are opaque to clients but not signed, so decode them
only into values you'd accept from the client anyway.

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

```dart
final app = GisilaApp(
  config: AppConfig(
    authenticator: CompositeAuthenticator([
      JwtAuthenticator(key: JwtKey.hmac(env.jwtSecret), algorithms: {'HS256'}),
      ApiKeyAuthenticator(lookup: (hash, _) => apiKeys.findActive(hash)),
    ]),
  ),
);
```

The first authenticator that finds a principal wins. One that throws (a
bad token) stops the search with a `401`. See
[authentication.md](authentication.md#combining-authenticators).

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

## Static files and single-page apps

```dart
// A built frontend at the root; the API's controllers still win.
app.serveStatic('/', 'web/dist',
    config: StaticFilesConfig(
      spaFallback: true,                                  // /orders/42 -> index.html
      maxAge: const Duration(hours: 1),
      immutable: RegExp(r'^assets/.*\.[0-9a-f]{8,}\.'),   // hashed build output
    ));

// Or just a folder under a prefix.
app.serveStatic('/uploads', 'storage/public');
```

* Controllers are matched first; a path with no file falls through to
  the next mount and then the JSON 404.
* `spaFallback` answers only `GET` requests for paths without a file
  extension that accept `text/html`, so API calls and missing assets
  still get a 404.
* Caching: files carry a weak `ETag` and `Last-Modified` and answer
  `304` to `If-None-Match` / `If-Modified-Since`. HTML is always
  `no-cache` (revalidated, so a deploy shows up at once); other files get
  `maxAge`, and names matching `immutable` a year.
* Safety: nothing outside the directory is served (`..` and encoded
  slashes are refused, symlinks leading out are treated as missing), no
  directory listings, no dotfiles such as `.env` unless `allowDotfiles`.
* Pages get the security headers too, including `X-Frame-Options: DENY`;
  add a CSP for them with `SecurityHeadersConfig.htmlContentSecurityPolicy`.
* Behind nginx or a CDN, let them serve the files instead when you can.

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
app.onStop(() => metrics.flush());

// SIGINT / SIGTERM: stop accepting connections, drain in-flight
// requests for up to 30 s, run onStop hooks, dispose singletons, exit.
await app.start(host: '0.0.0.0', port: 8080, stopOnSignals: true);
```

Without `stopOnSignals`, call `await app.stop()` yourself; pass
`force: true` to drop in-flight requests.

## Scheduled background jobs

Start the loop in an `onStart` hook and end it in `onStop`, so it
shares the app's lifetime (and its singletons):

```dart
var running = true;
late Future<void> loop;

app.onStart(() {
  loop = () async {
    while (running) {
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
  }();
});
app.onStop(() async {
  running = false;
  await loop;
});
```

For anything heavier, use gisila_queue.

## Metrics endpoint

Built in: turn on `AppConfig.metrics` and point Prometheus at
`/metrics`.

```dart
final app = GisilaApp(
  config: AppConfig(
    metrics: MetricsConfig(bearerToken: env['METRICS_TOKEN']),
  ),
);

// Your own metrics live next to the framework's:
final sent = app.metrics.counter('emails_sent_total',
    help: 'Emails sent.', labels: ['template']);
sent.inc({'template': 'welcome'});

final render = app.metrics.histogram('pdf_render_seconds', help: 'PDF time.');
await render.time(() => renderPdf(order));
```

What it records:

| Metric | Labels |
| ------ | ------ |
| `http_server_requests_total` | `method`, `route`, `status` |
| `http_server_request_duration_seconds` (histogram) | `method`, `route` |
| `http_server_requests_in_flight` | |
| `process_resident_memory_bytes`, `process_start_time_seconds` | |

`route` is the route template (`/users/<id>`), never the raw path, so
the number of series stays small. Requests no route matched are
`unmatched`; handlers mounted on the router by hand (docs, admin) are
`other`. Keep your own label values to a small fixed set too.

Who can read it: with `allow: (request) => ...`, whoever it accepts;
otherwise with `bearerToken` (16+ characters), requests that send
`Authorization: Bearer <token>`; otherwise only direct connections from
loopback without `X-Forwarded-For` / `Forwarded` / `X-Real-IP`, so a
reverse proxy on the same host doesn't publish it. Anyone else gets a
404.

### Several isolates on one port

Each isolate has its own numbers, and a scrape lands on whichever isolate
accepts the connection. Create a `MetricsHub` in the main isolate and
pass its `sendPort` to every isolate's config; a scrape then gathers and
sums all of them:

```dart
Future<void> main() async {
  final hub = MetricsHub();
  for (var i = 1; i < Platform.numberOfProcessors; i++) {
    await Isolate.spawn(serve, hub.sendPort);
  }
  await serve(hub.sendPort);
}

Future<void> serve(SendPort hub) async {
  final app = GisilaApp(config: AppConfig(metrics: MetricsConfig(hub: hub)));
  ...
  await app.start(port: 8080, shared: true);
}
```

An isolate that stops answering is dropped after three scrapes.

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

app.use(tracingMiddleware(otel.tracer('gisila')));
```

## OpenAPI / Swagger (with `shelf_openapi`)

`gisila` and `shelf_openapi` are independent packages. If you
also want auto-generated OpenAPI docs, add `shelf_openapi` to the
same controller class and run both generators:

```dart
import 'package:gisila/gisila.dart' hide Body, Path, Query, Header;
import 'package:shelf_openapi/shelf_openapi.dart' as openapi;

part 'users_controller.g.dart';                    // gisila
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
