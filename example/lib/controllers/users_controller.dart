import 'package:gisila/gisila.dart';

import '../models/user.dart';

part 'users_controller.g.dart';

@Controller('/users')
@RequireAuth()
class UsersController {
  UsersController();

  final Map<String, User> _store = <String, User>{};

  /// Public health-check exposed under the `/users` prefix even though
  /// the controller demands auth.
  @Get('/ping')
  @Public()
  Future<Map<String, Object?>> ping() async =>
      <String, Object?>{'status': 'ok', 'service': 'users'};

  @Get('/')
  @Permissions({'users:read'})
  Future<List<User>> listUsers({int? limit, int? offset}) async {
    final all = _store.values.toList();
    final start = offset ?? 0;
    final end =
        limit == null ? all.length : (start + limit).clamp(0, all.length);
    return all.sublist(start.clamp(0, all.length), end);
  }

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
  Future<User> getUser(String id) async {
    final u = _store[id];
    if (u == null) throw NotFound('User "$id" not found');
    return u;
  }

  @Post('/')
  @Permissions({'users:write'})
  Future<User> createUser(CreateUser body) async {
    final id = (_store.length + 1).toString();
    final user = User(
      id: id,
      name: body.name,
      email: body.email,
      roles: body.roles,
    );
    _store[id] = user;
    return user;
  }

  /// Accepts both `application/x-www-form-urlencoded` and JSON because
  /// the `LoginForm` class exposes both a `fromForm` and a `fromJson`
  /// factory. The generator picks `fromForm` when present.
  @Post('/login')
  @Public()
  Future<Map<String, Object?>> login(LoginForm body) async => <String, Object?>{
        'username': body.username,
        'remember': body.remember,
      };

  /// Multipart upload demo. The `file` parameter is automatically
  /// extracted by name from the form's files map; the optional `note`
  /// field is read from the same FormData via the JSON-shaped Map.
  @Post('/{id}/avatar')
  @Permissions({'users:write'})
  Future<Map<String, Object?>> uploadAvatar(
    String id,
    UploadedFile file,
  ) async {
    final bytes = await file.readAsBytes();
    return <String, Object?>{
      'id': id,
      'filename': file.name,
      'contentType': file.contentType.mimeType,
      'size': bytes.length,
    };
  }

  @Delete('/{id}')
  @AnyPermission({'admin', 'users:write'})
  Future<void> deleteUser(String id) async {
    if (!_store.containsKey(id)) throw NotFound('User "$id" not found');
    _store.remove(id);
  }

  @Get('/admin/audit')
  @Roles({'admin'})
  Future<Map<String, Object?>> audit() async => <String, Object?>{
        'count': _store.length,
        'ids': _store.keys.toList(),
      };
}
