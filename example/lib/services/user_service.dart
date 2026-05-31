/// Application service that owns user persistence + business logic.
///
/// This example uses an in-memory `Map` to keep dependencies minimal,
/// but the shape is the same as a "real" service backed by an ORM: the
/// service receives a [RequestContext] from the framework and can reach
/// a per-request DB session via `ctx.db<MySession>()`.
library;

import 'package:gisila/gisila.dart';

import '../models/user.dart';

/// Process-wide, in-memory user store. In a real app the
/// [DatabaseProvider] would hand the service a request-scoped
/// connection / session and this class would issue ORM queries through
/// it.
class InMemoryUserStore {
  final Map<String, User> _byId = <String, User>{};
  final Map<String, String> _passwords = <String, String>{};

  List<User> all() => _byId.values.toList();
  User? byId(String id) => _byId[id];
  User? byEmail(String email) =>
      _byId.values.where((u) => u.email == email).cast<User?>().firstOrNull;

  User insert({
    required String email,
    required String name,
    required String password,
    Set<String> roles = const <String>{},
  }) {
    final id = (_byId.length + 1).toString();
    final user = User(id: id, name: name, email: email, roles: roles);
    _byId[id] = user;
    _passwords[id] = password;
    return user;
  }

  User update(String id, {String? name, String? email}) {
    final existing = _byId[id]!;
    final updated = User(
      id: existing.id,
      name: name ?? existing.name,
      email: email ?? existing.email,
      roles: existing.roles,
    );
    _byId[id] = updated;
    return updated;
  }

  bool delete(String id) {
    _passwords.remove(id);
    return _byId.remove(id) != null;
  }

  bool checkPassword(String id, String password) => _passwords[id] == password;
}

extension on Iterable<User?> {
  User? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}

/// Single shared store - in a real app you'd inject this through a
/// `DatabaseProvider` and not keep a process-wide singleton.
final userStore = InMemoryUserStore();

class UserService extends Service {
  Future<List<User>> list({int? limit, int? offset}) async {
    final all = userStore.all();
    final start = offset ?? 0;
    final end =
        limit == null ? all.length : (start + limit).clamp(0, all.length);
    return all.sublist(start.clamp(0, all.length), end);
  }

  Future<User> getById(String id) async {
    final user = userStore.byId(id);
    if (user == null) throw NotFound('User "$id" not found');
    return user;
  }

  Future<User> register({
    required String email,
    required String password,
    required String name,
  }) async {
    if (userStore.byEmail(email) != null) {
      throw Conflict('An account with this email already exists.');
    }
    return userStore.insert(email: email, name: name, password: password);
  }

  Future<User> login({required String email, required String password}) async {
    final user = userStore.byEmail(email);
    if (user == null || !userStore.checkPassword(user.id, password)) {
      throw Unauthorized('Invalid email or password.');
    }
    return user;
  }

  Future<User> update(String id, {String? name, String? email}) async {
    if (userStore.byId(id) == null) {
      throw NotFound('User "$id" not found');
    }
    return userStore.update(id, name: name, email: email);
  }

  Future<void> delete(String id) async {
    if (!userStore.delete(id)) throw NotFound('User "$id" not found');
  }
}
