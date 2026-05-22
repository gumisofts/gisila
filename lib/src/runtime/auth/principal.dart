/// Identity bag returned by an [Authenticator] and attached to every
/// [RequestContext].
library gisila.runtime.auth.principal;

/// An authenticated caller.
///
/// The framework treats principals as opaque data; the only fields
/// inspected by built-in guards are [roles] and [permissions].
/// Anything else you put in [claims] is yours to use from controllers.
class Principal {
  const Principal({
    required this.id,
    this.roles = const <String>{},
    this.permissions = const <String>{},
    this.claims = const <String, Object?>{},
  });

  /// Stable identifier (e.g. user id, service account id).
  final String id;

  /// Role names assigned to the principal. Checked by the `@Roles`
  /// guard.
  final Set<String> roles;

  /// Permission scopes assigned to the principal. Checked by the
  /// `@Permissions` / `@AnyPermission` guards.
  final Set<String> permissions;

  /// Arbitrary extra claims (token issuer, expiry, tenant id, ...).
  final Map<String, Object?> claims;

  bool hasRole(String role) => roles.contains(role);
  bool hasPermission(String permission) => permissions.contains(permission);

  @override
  String toString() =>
      'Principal(id: $id, roles: $roles, permissions: $permissions)';
}
