/// Reusable guard helpers called by the generated handler code.
///
/// The generator emits a few lines like:
///
/// ```dart
/// final ctx = await __guard(
///   request,
///   requireAuth: true,
///   permissions: const {'users:write'},
///   anyPermission: const {},
///   roles: const {},
/// );
/// if (ctx is Response) return ctx;
/// ```
///
/// Keeping that block in user code as a single function call means the
/// generated output stays compact and the policy lives here.
library gisila.runtime.route_guard;

import 'dart:convert';

import 'package:shelf/shelf.dart';

import 'app.dart';
import 'auth/authenticator.dart';
import 'auth/permission_resolver.dart';
import 'auth_failure.dart';
import 'context.dart';
import 'exceptions.dart';

/// Guard result returned by [guardRequest].
///
/// On success the result is a [RequestContext]; on failure it is a
/// ready-made [Response] (401 / 403) the wrapper can short-circuit
/// with.
typedef GuardResult = Object;

/// Runs authentication + permission/role checks. Used by generated
/// handlers - hand-written code shouldn't normally need to call this.
Future<GuardResult> guardRequest(
  Request request, {
  required bool requireAuth,
  Set<String> permissions = const {},
  Set<String> anyPermission = const {},
  Set<String> roles = const {},
}) async {
  final ctx = RequestContext.maybeOf(request) ??
      RequestContext(requestId: 'unbound', request: request);

  final needsAuth = requireAuth ||
      permissions.isNotEmpty ||
      anyPermission.isNotEmpty ||
      roles.isNotEmpty;

  final app = GisilaApp.maybeOf(request);
  if (app == null) {
    // The framework wasn't booted via GisilaApp, so there is no
    // authenticator to honour the guards with. Fail closed.
    if (needsAuth) {
      return _errorResponse(InternalServerError(
        'Route guards need the request to go through GisilaApp.',
      ));
    }
    return ctx;
  }

  if (needsAuth) {
    final Authenticator auth = app.config.authenticator;
    final PermissionResolver resolver = app.config.permissionResolver;

    try {
      ctx.principal = await auth.authenticate(request);
    } catch (e, st) {
      return _errorResponse(authFailure(app, e, st, requestId: ctx.requestId));
    }
    if (ctx.principal == null) {
      return _errorResponse(Unauthorized());
    }

    final p = ctx.principal!;

    for (final perm in permissions) {
      if (!await resolver.hasPermission(p, perm)) {
        return _errorResponse(Forbidden('Missing permission "$perm"'));
      }
    }

    if (anyPermission.isNotEmpty) {
      var ok = false;
      for (final perm in anyPermission) {
        if (await resolver.hasPermission(p, perm)) {
          ok = true;
          break;
        }
      }
      if (!ok) {
        return _errorResponse(
            Forbidden('Missing any of permissions $anyPermission'));
      }
    }

    if (roles.isNotEmpty) {
      var ok = false;
      for (final role in roles) {
        if (await resolver.hasRole(p, role)) {
          ok = true;
          break;
        }
      }
      if (!ok) {
        return _errorResponse(Forbidden('Missing any of roles $roles'));
      }
    }
  }
  return ctx;
}

Response _errorResponse(HttpException e) => Response(
      e.statusCode,
      body: jsonEncode(e.toJson()),
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
