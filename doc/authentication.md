# Authentication

`gisila` does **not** assume how you authenticate users. Instead
it gives you two small interfaces - `Authenticator` and
`PermissionResolver` - and calls them from the guard runtime so the
annotations stay declarative.

This document covers the contract, the built-ins, and worked
recipes for the most common scenarios (static tokens, JWT, sessions,
mTLS).

## Table of contents

- [The `Authenticator` contract](#the-authenticator-contract)
- [The `PermissionResolver` contract](#the-permissionresolver-contract)
- [Default behaviour](#default-behaviour)
- [`StaticTokenAuthenticator`](#statictokenauthenticator)
- [Recipe: JWT (bearer)](#recipe-jwt-bearer)
- [Recipe: API key in header](#recipe-api-key-in-header)
- [Recipe: cookie session](#recipe-cookie-session)
- [Recipe: mTLS / client certs](#recipe-mtls--client-certs)
- [Recipe: database-backed permissions](#recipe-database-backed-permissions)
- [Recipe: per-tenant permission cache](#recipe-per-tenant-permission-cache)
- [Throwing from `authenticate`](#throwing-from-authenticate)
- [Testing your authenticator](#testing-your-authenticator)

## The `Authenticator` contract

```dart
abstract class Authenticator {
  const Authenticator();
  Future<Principal?> authenticate(Request request);
}
```

Implementations should:

* Return a fully populated `Principal` when the caller is
  authenticated.
* Return `null` for **anonymous** requests (no credentials, expired
  cookie, etc.). The framework returns `401` only when a guarded
  route actually requires auth.
* `throw` only for genuinely malformed credentials (e.g. a corrupt
  JWT signature). The framework catches the exception and surfaces
  the message in the `401` envelope.

`Principal`:

```dart
class Principal {
  const Principal({
    required this.id,
    this.roles = const <String>{},
    this.permissions = const <String>{},
    this.claims = const <String, Object?>{},
  });
}
```

`roles` and `permissions` feed the built-in resolver; `claims` is a
free-form bag (issuer, expiry, tenant id, locale) that survives into
your handlers via `ctx.principal!.claims`.

## The `PermissionResolver` contract

```dart
abstract class PermissionResolver {
  const PermissionResolver();
  Future<bool> hasPermission(Principal principal, String permission);
  Future<bool> hasRole(Principal principal, String role);
}
```

The default - `ClaimsPermissionResolver` - just reads the
`principal.permissions` / `principal.roles` sets. Implement your own
to consult a database, OPA, or a SaaS authz product.

The resolver is called **once per listed scope** per request. Cache
aggressively if your store is slow.

## Default behaviour

```dart
AppConfig(); // no authenticator, no resolver overridden
```

* `authenticator` defaults to `NullAuthenticator`, which always
  returns `null`. Any guarded route therefore returns `401`.
* `permissionResolver` defaults to `ClaimsPermissionResolver`.

This is intentional: a brand-new app cannot accidentally expose
guarded routes.

## `StaticTokenAuthenticator`

The simplest "real" authenticator, ideal for tests, demos, and tiny
internal services:

```dart
const StaticTokenAuthenticator({
  'admin-token': Principal(id: 'admin', roles: {'admin'},
      permissions: {'users:read', 'users:write'}),
  'reader-token': Principal(id: 'reader', permissions: {'users:read'}),
});
```

It looks for `Authorization: Bearer <token>` and maps the token to a
pre-registered principal. Pass `scheme: 'Token'` to use a different
auth scheme.

Never check tokens into VCS in production. For real deployments, see
the JWT recipe below.

## Recipe: JWT (bearer)

Use any JWT package on pub.dev (e.g. `dart_jsonwebtoken`,
`corsac_jwt`). The shape stays the same:

```dart
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:gisila/gisila.dart';

class JwtAuthenticator extends Authenticator {
  const JwtAuthenticator(this._secret);
  final String _secret;

  @override
  Future<Principal?> authenticate(Request request) async {
    final header = request.headers['authorization'];
    if (header == null || !header.startsWith('Bearer ')) return null;

    final token = header.substring('Bearer '.length).trim();
    final JWT parsed;
    try {
      parsed = JWT.verify(token, SecretKey(_secret));
    } on JWTExpiredException {
      throw Unauthorized('Token expired');
    } on JWTException catch (e) {
      throw Unauthorized('Invalid token: ${e.message}');
    }

    final payload = parsed.payload as Map<String, dynamic>;
    final scope = (payload['scope'] as String?) ?? '';

    return Principal(
      id: payload['sub'] as String,
      roles: ((payload['roles'] as List?) ?? const []).cast<String>().toSet(),
      permissions: scope.split(' ').where((s) => s.isNotEmpty).toSet(),
      claims: payload,
    );
  }
}
```

Wire it up:

```dart
final app = GisilaApp(
  config: AppConfig(
    authenticator: JwtAuthenticator(Platform.environment['JWT_SECRET']!),
  ),
);
```

Tips:

* Use the `claims` map to forward useful metadata to your handlers -
  `ctx.principal!.claims['tenant_id']`.
* Cache the JWKS / signing key if you're using rotating keys.
* Validate `aud` / `iss` inside `authenticate` and throw
  `Unauthorized` on mismatch.

## Recipe: API key in header

```dart
class ApiKeyAuthenticator extends Authenticator {
  ApiKeyAuthenticator(this._lookup);
  final Future<Principal?> Function(String key) _lookup;

  @override
  Future<Principal?> authenticate(Request request) async {
    final key = request.headers['x-api-key'];
    if (key == null || key.isEmpty) return null;
    return _lookup(key);
  }
}

final app = GisilaApp(
  config: AppConfig(
    authenticator: ApiKeyAuthenticator((key) async {
      final row = await db.apiKeys.where((k) => k.hash.eq(_hash(key))).first;
      if (row == null) return null;
      return Principal(
        id: row.ownerId,
        permissions: row.scopes,
        claims: {'apiKeyId': row.id},
      );
    }),
  ),
);
```

## Recipe: cookie session

```dart
class SessionAuthenticator extends Authenticator {
  SessionAuthenticator(this._store);
  final SessionStore _store;

  @override
  Future<Principal?> authenticate(Request request) async {
    final cookie = request.headers['cookie'];
    final sid = _parseCookie(cookie, 'sid');
    if (sid == null) return null;
    final session = await _store.find(sid);
    if (session == null || session.expired) return null;
    return Principal(
      id: session.userId,
      roles: session.roles,
      permissions: session.permissions,
      claims: {'sessionId': sid},
    );
  }
}
```

Combine with a custom middleware that issues / rotates the cookie on
`/auth/login`; see [middleware.md](middleware.md).

## Recipe: mTLS / client certs

If you terminate TLS at a reverse proxy that injects
`X-Client-Cert` / `X-Client-DN`:

```dart
class MtlsAuthenticator extends Authenticator {
  const MtlsAuthenticator();

  @override
  Future<Principal?> authenticate(Request request) async {
    final dn = request.headers['x-client-dn'];
    if (dn == null) return null;
    return Principal(
      id: dn,
      roles: const {'internal-service'},
      claims: {'mtlsDn': dn},
    );
  }
}
```

## Recipe: database-backed permissions

If you want the principal to carry only the bare identity and look
the scopes up at request time:

```dart
class DatabasePermissionResolver extends PermissionResolver {
  DatabasePermissionResolver(this._db);
  final DbContext _db;

  // Per-process LRU - tune to your scale.
  final _cache = <String, Set<String>>{};

  @override
  Future<bool> hasPermission(Principal p, String permission) async {
    final perms = _cache[p.id] ??= await _loadPermissions(p.id);
    return perms.contains(permission);
  }

  @override
  Future<bool> hasRole(Principal p, String role) async {
    return p.roles.contains(role);
  }

  Future<Set<String>> _loadPermissions(String userId) async {
    final rows = await _db.userPermissions
        .where((r) => r.userId.eq(userId))
        .get();
    return rows.map((r) => r.permission).toSet();
  }
}

final app = GisilaApp(
  config: AppConfig(
    authenticator: JwtAuthenticator(secret),
    permissionResolver: DatabasePermissionResolver(db),
  ),
);
```

The resolver is consulted *only* for routes that actually have
permission annotations - unguarded routes pay zero overhead.

## Recipe: per-tenant permission cache

When permissions vary per `(user, tenant)` the cache key changes:

```dart
class TenantAwareResolver extends PermissionResolver {
  final _cache = <String, Set<String>>{};

  String _key(Principal p) => '${p.id}|${p.claims['tenantId']}';

  @override
  Future<bool> hasPermission(Principal p, String permission) async {
    final perms = _cache[_key(p)] ??= await _load(p);
    return perms.contains(permission);
  }
  ...
}
```

Invalidate the cache on permission change events (a small pub/sub on
the side, or a periodic TTL).

## Throwing from `authenticate`

Throwing is meaningful: it tells the framework "the credentials were
present and broken". Use it when:

* A JWT signature is invalid.
* A session cookie is recognised but the row was tombstoned.
* The auth header is malformed beyond "the user is just anonymous".

The thrown exception's `toString()` ends up in the response message
on the `401` envelope - keep it terse and generic so you don't leak
internals.

```dart
throw Unauthorized('Token rejected by issuer');
```

Or throw your own subclass:

```dart
class TokenExpired extends HttpException {
  TokenExpired() : super(401, 'Token expired', code: 'token_expired');
}
```

The framework's error mapper handles `HttpException` subclasses
specifically; see [error-handling.md](error-handling.md).

## Testing your authenticator

`Authenticator` is a plain interface - test it directly:

```dart
test('rejects expired JWTs', () async {
  final auth = JwtAuthenticator('s');
  final token = JWT({'sub': 'u1'}, ...).sign(SecretKey('s'),
      expiresIn: const Duration(seconds: -1));
  expect(
    () => auth.authenticate(Request(
      'GET', Uri.parse('http://x/'),
      headers: {'authorization': 'Bearer $token'},
    )),
    throwsA(isA<HttpException>().having((e) => e.statusCode, 'status', 401)),
  );
});
```

For controller-level tests, see [testing.md](testing.md).
