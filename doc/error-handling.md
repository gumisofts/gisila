# Error handling

`gisila_web` aims for a single rule: **never write an error response
by hand**. Throw a typed exception; the framework renders it.

The result is a uniform JSON envelope across every endpoint and every
error path - body decoding, permission denial, business-rule
violations, unhandled bugs. Clients only ever need to learn one
shape.

## Table of contents

- [The error envelope](#the-error-envelope)
- [The `HttpException` hierarchy](#the-httpexception-hierarchy)
- [Built-in subclasses](#built-in-subclasses)
- [Throwing from a handler](#throwing-from-a-handler)
- [Throwing from middleware](#throwing-from-middleware)
- [Custom exception subclasses](#custom-exception-subclasses)
- [Where errors get mapped](#where-errors-get-mapped)
- [Unhandled exceptions](#unhandled-exceptions)
- [Custom global error handler](#custom-global-error-handler)
- [Returning `Response` for fine-grained control](#returning-response-for-fine-grained-control)
- [Common scenarios](#common-scenarios)

## The error envelope

Every framework-rendered error has exactly this shape:

```json
{
  "error": {
    "status":  <int>,
    "message": "<human-readable>",
    "code":    "<machine-readable, optional>",
    "details": { ... optional structured payload ... }
  }
}
```

Examples:

```json
{"error":{"status":401,"message":"Authentication required","code":"unauthorized"}}
{"error":{"status":404,"message":"Todo \"42\" not found","code":"not_found"}}
{"error":{"status":429,"code":"too_many_requests","message":"Rate limit exceeded"}}
{"error":{"status":409,"code":"duplicate_email","message":"Email exists",
          "details":{"email":"alice@example.com"}}}
```

Clients can rely on `status`, optionally branch on `code`, and use
`details` for field-level reporting.

## The `HttpException` hierarchy

```dart
class HttpException implements Exception {
  HttpException(this.statusCode, this.message, {this.code, this.details});

  final int statusCode;
  final String message;
  final String? code;
  final Map<String, Object?>? details;

  Map<String, Object?> toJson();
}
```

Anything that *is* an `HttpException` (or extends it) is rendered as
the envelope above with HTTP status equal to `statusCode`. The
framework's error-mapping middleware does this for you - inside
handlers, middleware, the codec, and the auth guard.

## Built-in subclasses

| Class                  | Status | Default `code`        |
| ---------------------- | ------ | --------------------- |
| `BadRequest`           | 400    | (none)                |
| `Unauthorized`         | 401    | `unauthorized`        |
| `Forbidden`            | 403    | `forbidden`           |
| `NotFound`             | 404    | `not_found`           |
| `Conflict`             | 409    | `conflict`            |
| `TooManyRequests`      | 429    | `too_many_requests`   |
| `InternalServerError`  | 500    | `internal_error`      |
| `BadRequestException`  | 400    | `bad_request`         |

The `BadRequestException` subclass is what the JSON-coercion helpers
throw when the input is malformed; it lives in the codec module so
generated code can reference it without importing the exceptions
module, but it *is* an `HttpException`.

## Throwing from a handler

The idiomatic pattern:

```dart
@Get('/users/{id}')
Future<User> get(String id) async {
  final user = await repo.find(id);
  if (user == null) throw NotFound('User "$id" not found');
  return user;
}

@Post('/users')
Future<User> create(CreateUser body) async {
  if (await repo.existsByEmail(body.email)) {
    throw Conflict(
      'Email already in use',
      code: 'duplicate_email',
      details: {'email': body.email},
    );
  }
  return repo.create(body);
}
```

You never construct a `Response` and you never call `jsonEncode`. The
framework owns both.

## Throwing from middleware

Middleware throws the same exceptions:

```dart
Middleware requireFeatureFlag(String flag) {
  return (inner) => (request) async {
    if (request.headers['x-feature-flag'] != flag) {
      throw Forbidden('Feature not enabled for this caller',
          code: 'feature_disabled');
    }
    return inner(request);
  };
}
```

This is also how the built-in auth guard reports a `401`/`403`: it
returns a pre-rendered response rather than throwing (because it's
called from inside the per-route wrapper for performance), but the
shape is identical.

## Custom exception subclasses

Subclass to add a stable `code`, default message, or extra fields:

```dart
class TokenExpired extends HttpException {
  TokenExpired() : super(401, 'Access token expired', code: 'token_expired');
}

class QuotaExceeded extends HttpException {
  QuotaExceeded(this.limit, this.current)
      : super(429, 'Daily quota exceeded',
            code: 'quota_exceeded',
            details: {'limit': limit, 'current': current});
  final int limit;
  final int current;
}
```

In handlers:

```dart
if (count >= limit) throw QuotaExceeded(limit, count);
```

Clients now have a typed `code` to switch on, plus exact numbers in
`details`.

## Where errors get mapped

The pipeline diagram from [middleware.md](middleware.md), with error
handling highlighted:

```
... request id / cors / rate-limit / access log ...
        │
        ▼
   ┌────────────────────┐
   │   Error mapping    │  catches HttpException → JSON envelope
   │                    │  catches everything else → errorHandler
   └────────────────────┘
        │
        ▼
   ... your global middleware ...
        │
        ▼
   ... your handlers ...
        │
        └─ throws HttpException ─┐
        └─ throws anything else ─┤
                                ▼
                          mapped here
```

Two consequences worth remembering:

1. **The error mapper runs before** your access log middleware. The
   access log line therefore sees the *final* HTTP status, even when
   the response was generated from an exception.
2. **The error mapper runs after** the request-id middleware, so the
   error response carries the same `X-Request-Id` header your logs
   contain. Great for "give us the trace id" support tickets.

## Unhandled exceptions

Anything that **isn't** an `HttpException` falls into the "unhandled"
path. The default behaviour:

* Logs a record at `error` level via the configured `Logger`.
* Returns a generic `500 Internal Server Error` envelope:

  ```json
  {"error":{"status":500,"message":"Internal server error","code":"internal_error"}}
  ```

* The exception **message is not leaked** to the client. The full
  exception and stack trace are in the log only.

This is the safest possible default; if you want richer behaviour,
plug in a custom handler.

## Custom global error handler

```dart
AppConfig(
  errorHandler: (error, stack) {
    Sentry.captureException(error, stackTrace: stack);
    return Response.internalServerError(
      body: jsonEncode({
        'error': {
          'status': 500,
          'code': 'oops',
          'message': 'Unexpected error, support has been notified',
          'traceId': Sentry.lastEventId,
        }
      }),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  },
);
```

Notes:

* The handler runs **only** for exceptions that are not
  `HttpException` (built-in or yours). To customise rendering of
  business exceptions, subclass and override `toJson()`:

  ```dart
  class ValidationError extends HttpException {
    ValidationError(this.errors) : super(422, 'Validation failed');
    final List<FieldError> errors;
    @override
    Map<String, Object?> toJson() => {
      'error': {
        'status': 422,
        'message': message,
        'code': 'validation_error',
        'errors': errors.map((e) => e.toJson()).toList(),
      }
    };
  }
  ```

* The handler runs **after** the framework has already logged the
  exception. If you only want Sentry to receive it (no
  double-logging), set `logger` to a custom logger that skips
  unhandled-exception lines, or filter in Sentry.

## Returning `Response` for fine-grained control

When you genuinely need to emit something non-JSON (e.g. a binary
download, a redirect, a streaming response), return a `Response`
directly:

```dart
@Get('/reports/{id}.csv')
@Permissions({'reports:read'})
Future<Response> download(String id) async {
  final csv = await reports.render(id);
  return Response.ok(csv, headers: {
    'content-type': 'text/csv',
    'content-disposition': 'attachment; filename="$id.csv"',
  });
}
```

A returned `Response` is **never** rewritten by the framework's error
mapper (it's already a valid Shelf response). If you want to short-
circuit with an *error* response, prefer throwing `HttpException`
- consistency beats one-off `Response.internalServerError(...)`.

## Common scenarios

### Field-level validation errors

```dart
@Post('/users')
Future<User> create(CreateUser body) async {
  final errors = <String, String>{};
  if (body.email.isEmpty) errors['email'] = 'required';
  if (body.password.length < 8) errors['password'] = 'too short';
  if (errors.isNotEmpty) {
    throw BadRequest('Invalid input',
        code: 'validation_error', details: {'fields': errors});
  }
  return repo.create(body);
}
```

### "404 vs 403" disambiguation

Some APIs intentionally return `404` even when the resource exists
but the caller can't see it (to avoid leaking existence). The
permission guard returns `403` by default - if you want `404`,
throw it yourself instead:

```dart
@Get('/secret-vault/{id}')
@RequireAuth()
Future<Vault> get(String id, RequestContext ctx) async {
  final vault = await repo.find(id);
  if (vault == null || vault.ownerId != ctx.principal!.id) {
    throw NotFound('No such vault');
  }
  return vault;
}
```

### Mapping a third-party exception

Suppose your DB driver throws `DbException` on conflicts:

```dart
@Post('/users')
Future<User> create(CreateUser body) async {
  try {
    return await repo.create(body);
  } on DbException catch (e) when (e.code == '23505') {
    throw Conflict('Email already in use',
        code: 'duplicate_email', details: {'email': body.email});
  }
}
```

### Returning a domain-specific error code consistently

Define a subclass once and use it everywhere:

```dart
class PaymentDeclined extends HttpException {
  PaymentDeclined(String reason)
      : super(402, 'Payment was declined',
            code: 'payment_declined', details: {'reason': reason});
}
```

Now any handler that processes a payment can `throw PaymentDeclined(...)`
and clients always see the same envelope.
