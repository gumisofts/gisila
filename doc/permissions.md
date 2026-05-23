# Permissions and access control

`gisila_web` makes "this route requires X" a one-liner. Every guard
annotation is processed at build time by the same generator that
emits the route wiring, so the check is **always** in front of your
handler - you can't forget it.

This document covers the five guard annotations, the precedence
rules between class and method level, and the runtime contract that
backs them.

## Table of contents

- [The five annotations at a glance](#the-five-annotations-at-a-glance)
- [The runtime contract](#the-runtime-contract)
- [Precedence rules](#precedence-rules)
- [`@RequireAuth`](#requireauth)
- [`@Permissions`](#permissions)
- [`@AnyPermission`](#anypermission)
- [`@Roles`](#roles)
- [`@Public`](#public)
- [Combining guards](#combining-guards)
- [Stacking class-level and method-level](#stacking-class-level-and-method-level)
- [Responses on failure](#responses-on-failure)
- [Programmatic checks](#programmatic-checks)
- [Custom guard logic](#custom-guard-logic)
- [Best practices](#best-practices)

## The five annotations at a glance

| Annotation                | Targets         | Implies `RequireAuth` | Semantics                                |
| ------------------------- | --------------- | --------------------- | ---------------------------------------- |
| `@RequireAuth()`          | class or method | -                     | Caller must be authenticated.            |
| `@Permissions({...})`     | class or method | yes                   | Must hold **every** listed permission.   |
| `@AnyPermission({...})`   | class or method | yes                   | Must hold **at least one** permission.   |
| `@Roles({...})`           | class or method | yes                   | Must hold **at least one** role.         |
| `@Public()`               | method only     | -                     | Open route, overrides class-level guards.|

All of them are plain `const`-constructable annotations - no closures,
no factories.

## The runtime contract

For every guarded route the generator emits a single call:

```dart
final result = await guardRequest(
  request,
  requireAuth: <bool>,
  permissions: const <String>{...},
  anyPermission: const <String>{...},
  roles: const <String>{...},
);
if (result is Response) return result;     // 401 or 403
final ctx = result as RequestContext;
// ... your handler runs ...
```

`guardRequest`:

1. Looks up the `GisilaApp` attached to the request context.
2. Calls `app.config.authenticator.authenticate(request)`.
3. Returns a `401` if authentication is required but no principal was
   resolved.
4. Calls `app.config.permissionResolver` for each `permission` /
   `role` listed.
5. Returns a `403` on the first failed check.
6. Otherwise returns the `RequestContext` (with `principal` set) and
   your handler runs.

You can implement custom `Authenticator` and `PermissionResolver`
behaviours - see [authentication.md](authentication.md).

## Precedence rules

```
                     ┌──────────────────────┐
                     │  Method-level @Public │ ───► route is open, stop
                     └──────────────────────┘
                                  │
                                  ▼
        (union of class-level and method-level guards)
                                  │
                                  ▼
                  requireAuth = class.requireAuth
                                 OR method.requireAuth
                                 OR any guard set is non-empty
                  permissions  = class.permissions ∪ method.permissions
                  anyPermission = class.anyPermission ∪ method.anyPermission
                  roles        = class.roles ∪ method.roles
```

The mental model:

* `@Public` is an **escape hatch** that wins outright.
* Otherwise, method-level guards **add to** class-level guards. There
  is no "narrower wins" rule - if the class demands `users:read`,
  every method requires `users:read`. The method can add more.
* "Any guard non-empty" implies `RequireAuth`. You can drop the
  explicit `@RequireAuth()` whenever you've already attached a
  `@Permissions` / `@AnyPermission` / `@Roles`.

## `@RequireAuth`

Demand that a principal be present. Useful when a route doesn't need
specific permissions but does need to know **who** is calling.

```dart
@Get('/me')
@RequireAuth()
Future<Map<String, Object?>> me(RequestContext ctx) async => {
      'id': ctx.principal!.id,
      'roles': ctx.principal!.roles.toList(),
    };
```

At the class level it applies to every route:

```dart
@Controller('/account')
@RequireAuth()
class AccountController {
  @Get('/me') Future<...> me(...) async => ...;
  @Put('/me') Future<...> update(...) async => ...;

  // explicit opt-out:
  @Get('/forgot-password') @Public()
  Future<...> forgot(...) async => ...;
}
```

## `@Permissions`

All listed permissions must be present.

```dart
@Post('/{id}/publish')
@Permissions({'posts:write', 'posts:publish'})
Future<Post> publish(String id) async => ...;
```

The set is a Dart `Set<String>` literal - duplicates are ignored, and
your team is free to use whatever naming convention fits (`scope`
strings, dotted paths, etc.). The framework only does set membership
on the principal's `permissions` set (via the
`PermissionResolver`).

## `@AnyPermission`

At least one listed permission must be present. Useful when several
admin-ish flags should each unlock a route.

```dart
@Delete('/{id}')
@AnyPermission({'admin', 'posts:delete', 'moderator'})
Future<void> delete(String id) async => ...;
```

You can stack `@Permissions` and `@AnyPermission` on the same route:
both checks have to pass.

```dart
@Get('/admin/reports')
@Permissions({'reports:read'})            // must have base read scope
@AnyPermission({'admin', 'auditor'})       // AND one of these tiers
Future<Report> report() async => ...;
```

## `@Roles`

At least one listed role must be present. Conceptually identical to
`@AnyPermission` but uses the role resolver instead of the permission
resolver, giving you a clean separation between RBAC and ABAC layers.

```dart
@Get('/admin/audit')
@Roles({'admin', 'security-officer'})
Future<AuditLog> audit() async => ...;
```

`@Roles` plays the same way at the class level:

```dart
@Controller('/admin')
@Roles({'admin'})
class AdminController { ... }
```

## `@Public`

Overrides every class-level guard for a single method.

```dart
@Controller('/auth')
@RequireAuth()                            // most routes need auth
class AuthController {
  @Post('/login') @Public()               // ... but login obviously not
  Future<TokenResponse> login(LoginBody body) async => ...;

  @Post('/refresh') @Public()
  Future<TokenResponse> refresh(RefreshBody body) async => ...;

  @Post('/logout')                        // logout still requires auth
  Future<void> logout(RequestContext ctx) async => ...;
}
```

You cannot put `@Public()` on a class; if you mean "no routes here
need auth", simply omit the guards.

## Combining guards

Guards combine **additively** within a single method:

```dart
@Post('/finance/transfer')
@RequireAuth()
@Permissions({'finance:write'})
@AnyPermission({'cfo', 'cco'})
@Roles({'finance-team'})
Future<TransferReceipt> transfer(TransferBody body) async => ...;
```

The order in source doesn't matter; the generator unions everything.
A request reaches `transfer` only when **all** of the following are
true:

1. Authenticated (implied by every other guard anyway).
2. Has `finance:write` permission.
3. Has at least one of `cfo` or `cco`.
4. Has the `finance-team` role.

## Stacking class-level and method-level

A common pattern is "everyone authenticated, admins only for write":

```dart
@Controller('/posts')
@RequireAuth()
class PostsController {
  @Get('/')                                 // any authenticated user
  Future<List<Post>> list() async => ...;

  @Get('/{id}')
  Future<Post> get(String id) async => ...;

  @Post('/')
  @Permissions({'posts:write'})            // class auth + write
  Future<Post> create(CreatePost body) async => ...;

  @Delete('/{id}')
  @Roles({'admin'})                        // class auth + admin role
  Future<void> delete(String id) async => ...;

  @Get('/health') @Public()                 // skip both
  Future<Map<String, Object?>> health() async => {'ok': true};
}
```

## Responses on failure

The framework emits a uniform JSON envelope - no need to format
anything yourself.

```http
HTTP/1.1 401 Unauthorized
content-type: application/json; charset=utf-8

{"error":{"status":401,"message":"Authentication required","code":"unauthorized"}}
```

```http
HTTP/1.1 403 Forbidden
content-type: application/json; charset=utf-8

{"error":{"status":403,"message":"Missing permission \"posts:write\"","code":"forbidden"}}
```

```http
HTTP/1.1 403 Forbidden

{"error":{"status":403,"message":"Missing any of permissions {admin, posts:delete}","code":"forbidden"}}
```

```http
HTTP/1.1 403 Forbidden

{"error":{"status":403,"message":"Missing any of roles {admin, security-officer}","code":"forbidden"}}
```

If the `Authenticator` threw (e.g. a JWT had a corrupt signature) the
exception message replaces the default `Authentication required`
text:

```http
HTTP/1.1 401 Unauthorized

{"error":{"status":401,"message":"FormatException: invalid base64","code":"unauthorized"}}
```

## Programmatic checks

Sometimes you need an "if admin, also include sensitive fields"
branch inside a handler. The principal is always at `ctx.principal`:

```dart
@Get('/users/{id}')
@RequireAuth()
Future<Map<String, Object?>> get(String id, RequestContext ctx) async {
  final user = await repo.find(id);
  return user.toJson(includeAudit: ctx.principal!.hasRole('admin'));
}
```

The `Principal` exposes:

```dart
class Principal {
  final String id;
  final Set<String> roles;
  final Set<String> permissions;
  final Map<String, Object?> claims;       // for things like tenant id
  bool hasRole(String role);
  bool hasPermission(String permission);
}
```

`hasRole` / `hasPermission` are pure set lookups - **do not** go
through the `PermissionResolver`. If your resolver consults a
database, prefer a small in-controller helper that calls
`app.config.permissionResolver` so the same cache/lookup path is
used.

## Custom guard logic

Three escape hatches when the built-in guards aren't enough:

### 1. Custom `PermissionResolver`

The cleanest way to plug in a database / OPA / external service while
keeping the annotations. See [authentication.md](authentication.md).

### 2. Custom middleware

For ownership checks ("user can only edit their own posts") write a
named middleware:

```dart
Middleware ownershipMiddleware() {
  return (inner) => (Request request) async {
    final ctx = RequestContext.maybeOf(request)!;
    final id = (Router().params(request)['id']) ??
        request.url.pathSegments.last;
    final post = await repo.find(id);
    if (post.authorId != ctx.principal!.id &&
        !ctx.principal!.hasRole('admin')) {
      throw Forbidden('Not your post');
    }
    return inner(request);
  };
}

app.registerNamedMiddleware('ownership', ownershipMiddleware());
```

Then in the controller:

```dart
@Put('/{id}')
@Permissions({'posts:write'})
@UseMiddleware('ownership')
Future<Post> update(String id, UpdatePost body) async => ...;
```

See [middleware.md](middleware.md) for details.

### 3. Throwing inside the handler

For truly one-off checks, throw `Forbidden` / `Unauthorized`
yourself:

```dart
@Get('/internal/cache/{key}')
@Roles({'admin'})
Future<Map<String, Object?>> peek(String key, RequestContext ctx) async {
  if (ctx.request.headers['x-debug-token'] != _expected) {
    throw Forbidden('Debug token required');
  }
  return cache.peek(key);
}
```

## Best practices

* **Prefer class-level `@RequireAuth`** in controllers where the
  *exception* is the open route. It's harder to forget and easier to
  review.
* **Name permissions like a hierarchy** - `users:read`, `users:write`,
  `users:admin` makes it obvious at a glance what a route needs.
* **Use `@Roles` for coarse buckets, `@Permissions` for granular
  scopes.** Mixing both is fine; just pick a convention and stick to
  it.
* **Don't reimplement the guard logic** inside handlers - if you find
  yourself writing the same `if (!principal.hasRole(...))` block in
  three controllers, promote it to a named middleware.
* **Audit failed guards.** Hook a `Logger` that watches for
  `status: 403` events; spikes often signal token leaks or scope
  misconfigurations.
