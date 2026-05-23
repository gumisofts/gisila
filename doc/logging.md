# Logging

`gisila_web` ships with a small structured-logging stack: a `Logger`
interface, a default `ConsoleLogger` that supports plain-text and JSON
output, and a per-request middleware that emits one log record per
HTTP request.

Every framework-internal log call goes through the same `Logger`, so
swapping in your own sink immediately catches everything: access logs,
unhandled exceptions, startup messages, hooks fired by your handlers.

## Table of contents

- [Quick start](#quick-start)
- [Log levels](#log-levels)
- [Log formats](#log-formats)
- [Anatomy of a `LogEvent`](#anatomy-of-a-logevent)
- [Logging from your handlers](#logging-from-your-handlers)
- [Per-request access log](#per-request-access-log)
- [Capturing request/response bodies](#capturing-requestresponse-bodies)
- [Custom log sinks](#custom-log-sinks)
- [Recipe: write to a file (with rotation)](#recipe-write-to-a-file-with-rotation)
- [Recipe: ship to a syslog / OTLP collector](#recipe-ship-to-a-syslog--otlp-collector)
- [Recipe: redact secrets](#recipe-redact-secrets)
- [Recipe: sample noisy requests](#recipe-sample-noisy-requests)
- [Testing log output](#testing-log-output)

## Quick start

```dart
final app = GisilaApp(
  config: AppConfig(
    logLevel: LogLevel.info,
    logFormat: LogFormat.text,    // or LogFormat.json
    logRequests: true,            // per-request access log
  ),
);
```

That's it. You get one record per request, plus startup messages,
plus any error that escapes your handlers.

```
2026-05-22T14:01:00Z [INFO ] gisila_web listening on http://0.0.0.0:8080 ...
2026-05-22T14:01:05Z [INFO ] req=f1q...  user=u1  GET /users/me -> 200 (3ms) ...
2026-05-22T14:01:09Z [WARN ] req=f7k...                POST /tasks  -> 422 (12ms) ...
2026-05-22T14:01:12Z [ERROR] req=...     user=u9  Unhandled exception in handler error=Bad State ...
```

## Log levels

```dart
enum LogLevel {
  trace,
  debug,
  info,           // default
  warning,
  error,
  fatal,
  off,            // disables everything below
}
```

* `AppConfig.logLevel` sets the minimum severity emitted by the
  default `ConsoleLogger`. Records below that threshold are dropped
  cheaply (no formatting, no allocation).
* If you pass a custom `Logger`, its own `level` getter wins.
* `LogLevel.off` is shorthand for "completely silent" - useful in
  tests.

`trace` and `debug` are meant for development. In production keep
`info` or higher; consider `warning` for very high-throughput
services.

## Log formats

```dart
enum LogFormat { text, json }
```

### Text (default)

Designed for `tail -f` and humans:

```
2026-05-22T14:01:05.123Z [INFO ] req=f1qsK3Bz user=u1
   GET /users/me -> 200 (3ms)
   method=GET path=/users/me status=200 duration_ms=3 remote=10.0.0.1:55230
```

### JSON

Designed for log shippers (ELK, Loki, Datadog, OpenTelemetry):

```json
{"ts":"2026-05-22T14:01:05.123Z","level":"info",
 "msg":"GET /users/me -> 200 (3ms)",
 "requestId":"f1qsK3Bz","principalId":"u1",
 "method":"GET","path":"/users/me","status":200,
 "duration_ms":3,"remote":"10.0.0.1:55230"}
```

One record per line, valid JSON, all framework fields are top-level
so you can index without nested-field parsers.

## Anatomy of a `LogEvent`

```dart
class LogEvent {
  final LogLevel level;
  final String message;
  final DateTime timestamp;       // UTC

  final String? requestId;        // from RequestContext
  final String? principalId;      // from Principal.id

  final Object? error;
  final StackTrace? stackTrace;

  final Map<String, Object?> fields;
}
```

A custom sink receives `LogEvent` directly - you control the
serialisation, batching, and transport.

## Logging from your handlers

There are three ways to add records:

### 1. Reach for the framework logger

```dart
@Get('/expensive')
@RequireAuth()
Future<Map<String, Object?>> expensive(RequestContext ctx) async {
  final app = GisilaApp.maybeOf(ctx.request)!;
  app.config.logger.info('starting expensive task',
      fields: {'requestId': ctx.requestId});
  ...
}
```

### 2. Build your own logger and inject it via DI

If your controllers already accept dependencies, just give them a
`Logger`:

```dart
class JobsController {
  JobsController(this._logger);
  final Logger _logger;
  ...
}
```

### 3. Decorate the framework logger with request context

Wrap the framework logger once per request so every record carries
`requestId` / `principalId` automatically:

```dart
class ScopedLogger extends Logger {
  ScopedLogger(this._inner, this._ctx);
  final Logger _inner;
  final RequestContext _ctx;

  @override
  LogLevel get level => _inner.level;

  @override
  void log(LogEvent event) {
    _inner.log(LogEvent(
      level: event.level,
      message: event.message,
      timestamp: event.timestamp,
      requestId: event.requestId ?? _ctx.requestId,
      principalId: event.principalId ?? _ctx.principal?.id,
      error: event.error,
      stackTrace: event.stackTrace,
      fields: event.fields,
    ));
  }
}
```

Stash it on `ctx.extra['logger']` from a middleware.

## Per-request access log

When `AppConfig.logRequests` is `true` (default), the framework
registers `requestLoggingMiddleware`. It produces a single record
per request with these standard fields:

| Field         | Meaning                                          |
| ------------- | ------------------------------------------------ |
| `method`      | HTTP verb.                                       |
| `path`        | Requested URL path.                              |
| `query`       | Raw query string (possibly empty).               |
| `status`      | HTTP response status code.                       |
| `duration_ms` | Wall-clock time the request took.                |
| `remote`      | `X-Forwarded-For` or peer `host:port`.           |
| `requestId`   | Echoed via the response `X-Request-Id` header.   |
| `principalId` | Only when authenticated (after the guard).       |

If your handler throws **before** the middleware returns, the
middleware logs an `error`-level record with the stack trace and
re-throws so the global error mapper can emit the response.

## Capturing request/response bodies

Two flags on `AppConfig` toggle body capture:

```dart
AppConfig(
  logRequestBody: true,    // off by default
  logResponseBody: true,   // off by default
);
```

* The middleware reads the body fully into memory, logs it (truncated
  to ~2 KiB by default), and replays it to the handler / downstream
  middleware.
* Useful in dev / staging; risky in production with large payloads or
  PII. Combine with a [redacting wrapper](#recipe-redact-secrets)
  before enabling.

If you only want bodies for failing requests, write your own
middleware - the built-in one is intentionally simple.

## Custom log sinks

Implement `Logger`:

```dart
class FileLogger extends Logger {
  FileLogger(this._file, {this.level = LogLevel.info});
  final File _file;

  @override
  final LogLevel level;

  IOSink? _sink;

  @override
  void log(LogEvent event) {
    if (!(event.level >= level)) return;
    _sink ??= _file.openWrite(mode: FileMode.append);
    _sink!.writeln(jsonEncode({
      'ts': event.timestamp.toIso8601String(),
      'level': event.level.name,
      'msg': event.message,
      'requestId': event.requestId,
      'principalId': event.principalId,
      if (event.error != null) 'error': event.error.toString(),
      ...event.fields,
    }));
  }
}

final app = GisilaApp(
  config: AppConfig(
    logger: FileLogger(File('/var/log/gisila_web.log')),
  ),
);
```

When you pass a custom `Logger`, `logLevel` and `logFormat` from
`AppConfig` are ignored - both are properties of the *default*
`ConsoleLogger`.

## Recipe: write to a file (with rotation)

For real rotation use a library (e.g. `logging_handlers` or pipe to
`logrotate`). A minimal home-grown rotator:

```dart
class RotatingFileLogger extends Logger {
  RotatingFileLogger(this._dir,
      {this.level = LogLevel.info, this.maxBytes = 10 * 1024 * 1024});

  final Directory _dir;
  @override
  final LogLevel level;
  final int maxBytes;

  late File _file = File('${_dir.path}/app.log');

  @override
  void log(LogEvent event) {
    if (!(event.level >= level)) return;
    final line = '${event.timestamp.toIso8601String()} '
        '[${event.level.name}] ${event.message}\n';
    if (_file.existsSync() && _file.lengthSync() > maxBytes) {
      _file.renameSync('${_file.path}.${DateTime.now().millisecondsSinceEpoch}');
      _file = File('${_dir.path}/app.log');
    }
    _file.writeAsStringSync(line, mode: FileMode.append, flush: false);
  }
}
```

## Recipe: ship to a syslog / OTLP collector

Use a fan-out logger that forwards to *both* console (for `docker logs`)
and your collector:

```dart
class FanOutLogger extends Logger {
  FanOutLogger(this._delegates);
  final List<Logger> _delegates;

  @override
  LogLevel get level =>
      _delegates.map((l) => l.level).reduce(
          (a, b) => a.priority < b.priority ? a : b);

  @override
  void log(LogEvent event) {
    for (final l in _delegates) l.log(event);
  }
}

final app = GisilaApp(
  config: AppConfig(
    logger: FanOutLogger([
      ConsoleLogger(level: LogLevel.info, format: LogFormat.json),
      OtlpLogger(endpoint: 'http://otel-collector:4317'),
    ]),
  ),
);
```

## Recipe: redact secrets

A wrapping logger lets you scrub fields before they leave the
process:

```dart
class RedactingLogger extends Logger {
  RedactingLogger(this._inner, this._sensitive);
  final Logger _inner;
  final Set<String> _sensitive;

  @override
  LogLevel get level => _inner.level;

  @override
  void log(LogEvent event) {
    final clean = <String, Object?>{
      for (final entry in event.fields.entries)
        entry.key: _sensitive.contains(entry.key) ? '***' : entry.value,
    };
    _inner.log(LogEvent(
      level: event.level,
      message: event.message,
      timestamp: event.timestamp,
      requestId: event.requestId,
      principalId: event.principalId,
      error: event.error,
      stackTrace: event.stackTrace,
      fields: clean,
    ));
  }
}

final app = GisilaApp(
  config: AppConfig(
    logger: RedactingLogger(
      ConsoleLogger(format: LogFormat.json),
      {'requestBody', 'responseBody', 'authorization', 'cookie'},
    ),
  ),
);
```

## Recipe: sample noisy requests

To keep the volume of access logs sane, drop a fraction of
2xx responses on hot paths:

```dart
class SampledAccessLog extends Logger {
  SampledAccessLog(this._inner, {this.keepEvery = 10});
  final Logger _inner;
  final int keepEvery;
  int _counter = 0;

  @override
  LogLevel get level => _inner.level;

  @override
  void log(LogEvent event) {
    final status = event.fields['status'];
    if (status is int && status < 400) {
      if (_counter++ % keepEvery != 0) return;
    }
    _inner.log(event);
  }
}
```

## Testing log output

`ConsoleLogger` accepts injectable sinks:

```dart
test('logs at info level', () {
  final lines = <String>[];
  final logger = ConsoleLogger(
    level: LogLevel.info,
    stdoutSink: lines.add,
    stderrSink: lines.add,
  );
  logger.info('hi');
  expect(lines, ['... [INFO ] hi']);
});
```

For a full request → response → log assertion, see
[testing.md](testing.md).
