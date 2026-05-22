/// Permission / authentication annotations.
///
/// Placed on a controller class or a single route method. The
/// generator emits a small guard block at the top of each generated
/// handler that calls the configured `Authenticator` /
/// `PermissionResolver`.
///
/// Guard precedence (most specific wins):
///
/// 1. A method-level [Public] always wins - the route is open.
/// 2. Otherwise, method-level [Permissions], [AnyPermission] or
///    [Roles] add to (do not replace) the class-level guards.
/// 3. A class-level [RequireAuth] forces authentication for every
///    route, but is overridden by method-level [Public].
library gisila.annotations.permission;

import 'package:meta/meta_meta.dart';

/// Marks a route (or every route in a controller) as requiring an
/// authenticated principal.
///
/// The framework's [Authenticator] is invoked; if no principal is
/// resolved, a `401 Unauthorized` response is returned and the handler
/// is never called.
@Target({TargetKind.classType, TargetKind.method})
class RequireAuth {
  const RequireAuth();
}

/// Marks a route as publicly accessible, overriding any class-level
/// [RequireAuth] / [Permissions] / [Roles] guards.
@Target({TargetKind.method})
class Public {
  const Public();
}

/// Requires every permission in [values]. Implies [RequireAuth].
///
/// ```dart
/// @Permissions({'users:read', 'users:write'})
/// Future<User> updateUser(...) async => ...;
/// ```
@Target({TargetKind.classType, TargetKind.method})
class Permissions {
  const Permissions(this.values);
  final Set<String> values;
}

/// Requires at least one permission in [values]. Implies [RequireAuth].
///
/// ```dart
/// @AnyPermission({'admin', 'super-admin'})
/// Future<void> deleteUser(String id) async => ...;
/// ```
@Target({TargetKind.classType, TargetKind.method})
class AnyPermission {
  const AnyPermission(this.values);
  final Set<String> values;
}

/// Requires the authenticated principal to hold at least one of the
/// listed [values] roles. Implies [RequireAuth].
@Target({TargetKind.classType, TargetKind.method})
class Roles {
  const Roles(this.values);
  final Set<String> values;
}
