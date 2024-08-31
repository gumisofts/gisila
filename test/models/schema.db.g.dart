part of 'schema.dart';

extension UserDb on User {
  Map<String, dynamic> toJson(
      {bool excludeNull = false, List<String>? exclude, List<String>? only}) {
    final json = {
      'id': id,
      'name': name,
    };
    if (excludeNull) {
      json.removeWhere((key, value) => value == null);
    }
    if (only != null) {
      json.removeWhere((key, value) => !only.contains(key));
    } else if (exclude != null) {
      json.removeWhere((key, value) => exclude.contains(key));
    }
    return json;
  }

  static User fromRow(ResultRow row) {
    final map = row.toColumnMap();
    return User(
      id: map["userId"] as int,
      name: map["name"] as String,
    );
  }

  static Iterable<User> fromResult(Result result) {
    return result.map(fromRow);
  }

  static Future<User> create({
    required String name,
  }) async {
    final model = User(
      name: name,
    );
    final data = model.toJson(excludeNull: true);
    final q = Query.insert(
      table: 'user',
      columns: data,
    );
    final res = await Database.execute(q.toString());
    return fromRow(res.first);
  }

  static Future<bool> delete(User user) async {
    final q = Query.delete(
      table: "user",
      operation: Operation('userId'.safeTk, Operator.eq, user.id),
    );
    try {
      await Database.execute(q.toString());
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<Iterable<User>> filter({
    required Operation? Function(UserQuery) where,
    List<String> orderBy = const [],
    int offset = 0,
    int? limit,
    List<Join> joins = const [],
  }) async {
    final tt = where(UserQuery());
    final query = Query.select(
      table: UserQuery.table,
      columns: UserQuery.columns,
      operation: tt,
      offset: offset,
      limit: limit,
      joins: tt == null ? [] : tt.joins,
    );
    final result = await Database.execute(query.toString());
    return fromResult(result);
  }

  static Future<User?> get(
      {required Operation Function(UserQuery) where}) async {
    final res = await filter(where: where);
    if (res.isEmpty) return null;
    return res.first;
  }
}

extension BookDb on Book {
  Map<String, dynamic> toJson(
      {bool excludeNull = false, List<String>? exclude, List<String>? only}) {
    final json = {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'authorId': authorId,
    };
    if (excludeNull) {
      json.removeWhere((key, value) => value == null);
    }
    if (only != null) {
      json.removeWhere((key, value) => !only.contains(key));
    } else if (exclude != null) {
      json.removeWhere((key, value) => exclude.contains(key));
    }
    return json;
  }

  static Book fromRow(ResultRow row) {
    final map = row.toColumnMap();
    return Book(
      id: map["bookId"] as int,
      title: map["title"] as String,
      subtitle: map["subtitle"] as String?,
      authorId: map["authorId"] as int,
    );
  }

  static Iterable<Book> fromResult(Result result) {
    return result.map(fromRow);
  }

  static Future<Book> create({
    required String title,
    required int authorId,
    String? subtitle,
  }) async {
    final model = Book(
      title: title,
      subtitle: subtitle,
      authorId: authorId,
    );
    final data = model.toJson(excludeNull: true);
    final q = Query.insert(
      table: 'book',
      columns: data,
    );
    final res = await Database.execute(q.toString());
    return fromRow(res.first);
  }

  static Future<bool> delete(Book book) async {
    final q = Query.delete(
      table: "book",
      operation: Operation('bookId'.safeTk, Operator.eq, book.id),
    );
    try {
      await Database.execute(q.toString());
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<Iterable<Book>> filter({
    required Operation? Function(BookQuery) where,
    List<String> orderBy = const [],
    int offset = 0,
    int? limit,
    List<Join> joins = const [],
  }) async {
    final tt = where(BookQuery());
    final query = Query.select(
      table: BookQuery.table,
      columns: BookQuery.columns,
      operation: tt,
      offset: offset,
      limit: limit,
      joins: tt == null ? [] : tt.joins,
    );
    final result = await Database.execute(query.toString());
    return fromResult(result);
  }

  static Future<Book?> get(
      {required Operation Function(BookQuery) where}) async {
    final res = await filter(where: where);
    if (res.isEmpty) return null;
    return res.first;
  }
}
