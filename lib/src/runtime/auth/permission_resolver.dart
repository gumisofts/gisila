/// Permission resolution abstraction.
///
/// The default implementation, [ClaimsPermissionResolver], simply
/// inspects the [Principal]'s `permissions` set. Plug in a custom
/// resolver to look permissions up in a database / OPA / etc.
library gisila.runtime.auth.permission_resolver;

import 'principal.dart';

/// Resolves whether a [Principal] holds a permission or a role.
abstract class PermissionResolver {
  const PermissionResolver();

  Future<bool> hasPermission(Principal principal, String permission);
  Future<bool> hasRole(Principal principal, String role);
}

/// Default resolver that reads from the principal's [Principal.permissions]
/// and [Principal.roles] sets.
class ClaimsPermissionResolver extends PermissionResolver {
  const ClaimsPermissionResolver();

  @override
  Future<bool> hasPermission(Principal principal, String permission) async =>
      principal.permissions.contains(permission);

  @override
  Future<bool> hasRole(Principal principal, String role) async =>
      principal.roles.contains(role);
}
