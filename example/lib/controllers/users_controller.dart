/// Thin users controller.
///
/// Every method's signature reads like a function: typed `Form`
/// parameter (input validation + cleaning), typed `Service` parameter
/// (business logic + persistence), optional `RequestContext` (for
/// principal / requestId / DB session access). No raw `Request`, no
/// inline permission checks, no `handleRequest(...)` wrapper.
library;

import 'package:gisila/gisila.dart';

import '../forms/user_forms.dart';
import '../models/user.dart';
import '../services/user_service.dart';

part 'users_controller.g.dart';

@Controller('/users')
@RequireAuth()
class UsersController {
  UsersController();

  /// Public health check exposed under the auth-protected controller
  /// thanks to `@Public()`.
  @Get('/ping')
  @Public()
  Future<Map<String, Object?>> ping() async =>
      <String, Object?>{'status': 'ok', 'service': 'users'};

  /// Per-route rate limit + typed query params.
  @Get(
    '/',
    config: RouteConfig(
      rateLimit: RateLimitConfig(requestsPerMinute: 60),
    ),
  )
  @Permissions({'users:read'})
  Future<List<User>> listUsers(
    UserService users, {
    int? limit,
    int? offset,
  }) {
    return users.list(limit: limit, offset: offset);
  }

  /// Public registration with per-route rate limit and the typed form
  /// pattern. No `Request`, no manual body parsing.
  @Post(
    '/',
    config: RouteConfig(
      rateLimit: RateLimitConfig(requestsPerMinute: 30),
    ),
  )
  @Public()
  Future<User> register(RegisterForm form, UserService users) {
    return users.register(
      email: form.email.value!,
      password: form.password.value!,
      name: form.name.value!,
    );
  }

  /// JSON or form-urlencoded login. The same [LoginForm] handles both.
  @Post('/login')
  @Public()
  Future<Map<String, Object?>> login(LoginForm form, UserService users) async {
    final user = await users.login(
      email: form.email.value!,
      password: form.password.value!,
    );
    return <String, Object?>{
      'user': user.toJson(),
      'remember': form.remember.value ?? false,
    };
  }

  /// Reads the principal off the [RequestContext].
  @Get('/me')
  Future<Map<String, Object?>> me(RequestContext ctx) async {
    final p = ctx.principal!;
    return <String, Object?>{
      'id': p.id,
      'roles': p.roles.toList(),
      'permissions': p.permissions.toList(),
      'requestId': ctx.requestId,
    };
  }

  @Get('/{id}')
  @Permissions({'users:read'})
  Future<User> getUser(String id, UserService users) => users.getById(id);

  @Patch('/{id}')
  @Permissions({'users:write'})
  Future<User> updateUser(
    String id,
    UpdateUserForm form,
    UserService users,
  ) {
    return users.update(id, name: form.name.value, email: form.email.value);
  }

  @Delete('/{id}')
  @AnyPermission({'admin', 'users:write'})
  Future<void> deleteUser(String id, UserService users) => users.delete(id);
}
