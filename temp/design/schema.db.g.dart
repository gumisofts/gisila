part of 'schema.dart';

// SELECT [DISTINCT] column_list
// FROM table_name
// [JOIN ...]
// [WHERE condition]
// [GROUP BY column_list]
// [HAVING condition]
// [ORDER BY column_list [ASC|DESC]]
// [LIMIT n]
// [OFFSET m];

class UserDb {
  static final table = '';
  static Iterable<User> fromResult(Result result) {
    final rows = result.toList().map((row) => row.toColumnMap());

    final users = rows.map((row) => User(id: row[''], firstName: row['']));

    return users;
  }

  Future<Iterable<User>> filter(Operation Function(UserQuery) where,
      {bool includeTodos = false, int? limit, int? offset, orderBy}) async {
    final operation = where(UserQuery());

    final query = Query.select(table: table, columns: [], operation: operation);

    final result = await Database.execute(query);
    var users = fromResult(result);

    if (includeTodos) {
      final todos = TodoDb.fromResult(result);

      users = users.map((user) =>
          user..todos = todos.where((todo) => todo.userId == user.id));
    }

    return users;
  }

  Future<User> create({required String firstName, String? lastName}) async {
    // execute sql and return all data
    return User(id: "", firstName: firstName);
  }

  Future<bool> delete(User user) async {
    // delete user here
    return false;
  }

  Future<int> deleteWhere(Operation Function(UserQuery) where) async {
    return 1;
  }

  Future<bool> deleteById(int id) async {
    return false;
  }
}

class TodoDb {
  static final table = 'todo';
  static Iterable<Todo> fromResult(Result result) {
    final rows = result.toList().map((row) => row.toColumnMap());

    final todos = rows.map((row) =>
        Todo(id: row[''], title: row[''], desc: row[''], userId: row['']));

    return todos;
  }

  // Future<Iterable<Todo>> filter(Operation Function(TodoQuery) where,
  //     {bool includeUser = false, int? limit, int? offset, orderBy}) async {
  //   final operation = where(TodoQuery());

  //   final query = Query.select(table: table, columns: [], operation: operation);

  //   final result = await Database.execute(query);
  //   var todos = fromResult(result);

  //   if (includeUser) {
  //     // final todos = TodoDb.fromResult(result);
  //     todos = todos.map((todo) => todo..user=);

  //     users = users.map((user) =>
  //         user..todos = todos.where((todo) => todo.userId == user.id));
  //   }

  //   return users;
  // }
}
