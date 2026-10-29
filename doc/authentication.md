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
- [`JwtAuthenticator` (built in)](#jwtauthenticator-built-in)
- [`ApiKeyAuthenticator` (built in)](#apikeyauthenticator-built-in)
- [Combining authenticators](#combining-authenticators)
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
[`JwtAuthenticator`](#jwtauthenticator-built-in) below.

## `JwtAuthenticator` (built in)

`JwtAuthenticator` verifies `Authorization: Bearer <jwt>` and turns the
claims into a `Principal`. `JwtSigner` issues tokens it accepts, so an app
that logs users in needs no other JWT package.

```dart
final key = JwtKey.hmac(Platform.environment['JWT_SECRET']!); // >= 32 bytes

final app = GisilaApp(
  config: AppConfig(
    authenticator: JwtAuthenticator(
      key: key,
      algorithms: {'HS256'},
      issuer: 'my-app',
      // Optional: load the user; return null to reject the token.
      toPrincipal: (claims, request) async {
        final user = await users.find(claims.subject);
        if (user == null || !user.isActive) return null;
        return Principal(
          id: '${user.id}',
          roles: {if (user.isStaff) 'staff'},
          claims: {'user': user},
        );
      },
    ),
  ),
);

// At login:
final signer = JwtSigner(
  key: key,
  algorithm: 'HS256',
  issuer: 'my-app',
  expiresIn: const Duration(days: 30),
);
final token = signer.sign(subject: '${user.id}');
```

Without `toPrincipal`, `sub` becomes the id, the `roles` claim (a list)
the roles, and `scope` (space-separated) plus `permissions` (a list) the
permissions. The whole payload lands in `principal.claims`.

What is checked, and why:

| Check | Default | Notes |
| ----- | ------- | ----- |
| Algorithm | `algorithms` (required) | The token's `alg` must be in the set. `none` is never accepted. |
| Key type | always | Each algorithm must fit the key: `JwtAuthenticator(key: <RSA key>, algorithms: {'HS256'})` throws, so a token can't be signed with your public key as an HMAC secret. |
| `exp` | required | Set `requireExpiry: false` for tokens without one. |
| `exp` / `nbf` / `iat` | `leeway: 30s` | Allowed clock skew. A future `iat` is rejected. |
| `iat` age | off | `maxAge: Duration(...)` also requires `iat`. |
| `iss` | off | `issuer: '...'` must match exactly. |
| `aud` | off | `audience: {...}` passes when the token's `aud` holds any of them. |
| `typ` | off | `requiredType: 'at+jwt'` keeps ID tokens out of an access-token API. |
| HMAC secret | 32 bytes | `JwtKey.hmac` throws on shorter secrets. |

A request without a bearer token is anonymous, so `@Public` routes work
and guarded routes answer `401 unauthorized`. A token that fails a check
answers `401` with code `token_expired` (refresh and retry) or
`invalid_token`; the reason isn't sent to the client.

Other places to read the token from (a cookie, a custom header):

```dart
JwtAuthenticator(
  key: key,
  algorithms: {'HS256'},
  tokenFromRequest: (request) => readCookie(request, 'session'),
);
```

### Asymmetric keys and key rotation

```dart
// RS256 / ES256: verify with the public key, sign with the private key.
JwtAuthenticator(key: JwtKey.rsaPublicPem(pem), algorithms: {'RS256'});
JwtSigner(key: JwtKey.rsaPrivatePem(privatePem), algorithm: 'RS256');

// Several keys, chosen by the token's `kid` (give each key an `id`).
JwtAuthenticator(
  keys: StaticJwtKeySet([
    JwtKey.hmac(newSecret, id: '2026-10'),
    JwtKey.hmac(oldSecret, id: '2026-04'),
  ]),
  algorithms: {'HS256'},
);
```

With more than one key, a token without `kid` is rejected rather than
tried against each key.

### Tokens from an identity provider (JWKS)

```dart
JwtAuthenticator(
  keys: RemoteJwks(Uri.parse('https://idp.example.com/.well-known/jwks.json')),
  algorithms: {'RS256'},
  issuer: 'https://idp.example.com/',
  audience: {'my-api'},
);
```

`RemoteJwks` caches the document for `cacheFor` (10 minutes), refetches
early when a token names an unknown `kid` (at most every 30 seconds), and
keeps using the old keys if a refresh fails. It ignores symmetric and
private keys in the document, and needs `https` (plain `http` only on
localhost).

Implement `JwtKeySet` yourself to load keys from somewhere else.

## `ApiKeyAuthenticator` (built in)

Keys are stored hashed: the authenticator hashes the key it receives
(SHA-256) and hands your `lookup` the hash, so the keys themselves never
sit in your database.

```dart
// Issuing a key: store the hash, show the key once.
final key = ApiKeyAuthenticator.generate(prefix: 'sk_live_');
await db.apiKeys.insert(hash: ApiKeyAuthenticator.hash(key), ownerId: user.id);

// Checking keys sent as `X-API-Key: <key>`.
final app = GisilaApp(
  config: AppConfig(
    authenticator: ApiKeyAuthenticator(
      lookup: (hash, request) async {
        final row = await db.apiKeys.findActiveByHash(hash);
        if (row == null) return null;            // -> 401 invalid_api_key
        return Principal(
          id: row.ownerId,
          permissions: row.scopes,
          claims: {'apiKeyId': row.id},
        );
      },
    ),
  ),
);
```

`generate` gives 256 random bits after an optional prefix; a prefix
makes leaked keys easy to spot (and to scan for). Use `header:` for
another header name or `keyFromRequest:` to read it from elsewhere.

## Combining authenticators

`CompositeAuthenticator` tries each in turn and takes the first
principal, e.g. JWTs from the browser app and API keys from scripts:

```dart
authenticator: CompositeAuthenticator([
  JwtAuthenticator(key: key, algorithms: {'HS256'}),
  ApiKeyAuthenticator(lookup: findKey),
]),
```

If one throws (a credential is present but wrong), the search stops with
that 401; a rejected token is never retried as something else. Give each
credential its own header (`Authorization` for JWTs, `X-API-Key` for
keys) so they don't collide.

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
    authenticator: JwtAuthenticator(key: key, algorithms: {'HS256'}),
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
  final key = JwtKey.hmac('a-test-secret-that-is-at-least-32-bytes');
  final auth = JwtAuthenticator(key: key, algorithms: {'HS256'});
  final token = JwtSigner(key: key, algorithm: 'HS256')
      .sign(subject: 'u1', expiresIn: const Duration(minutes: -5));
  expect(
    () => auth.authenticate(Request(
      'GET', Uri.parse('http://x/'),
      headers: {'authorization': 'Bearer $token'},
    )),
    throwsA(isA<HttpException>()
        .having((e) => e.code, 'code', 'token_expired')),
  );
});
```

For controller-level tests, see [testing.md](testing.md).
