import 'package:pg_dorm/pg_dorm.dart';
part 'schema.db.g.dart';
part 'schema.query.g.dart';

class User {
  User({required String name, this.id}) {
    _name = name;
  }

  final _updatedFields = <String, dynamic>{};
  int? id;
  Future<void> save() async {
    if (_updatedFields.isNotEmpty) {
      final query = Query.update(
        table: "user",
        columns: _updatedFields,
        operation: Operation("userId".safeTk, Operator.eq, id),
      );
      await Database.execute(query.toString());
    }
  }

  Future<bool> delete() async {
    return UserDb.delete(this);
  }

  late String _name;
  String get name => _name;
  set name(String m) {
    _updatedFields['name'] = m;
    _name = m;
  }
}

class Book {
  Book({
    required String title,
    required int authorId,
    this.id,
    String? subtitle,
  }) {
    _title = title;
    _subtitle = subtitle;
    _authorId = authorId;
  }
  late int _authorId;
  int get authorId => _authorId;
  set authorId(int id) {
    _updatedFields["author"] = id;
    _authorId = id;
  }

  // ModelHolder<User>? _getauthor;
  // Future<User?> get author {
  // _getauthor ??= ModelHolder<User>(
  //   getModelInstance: () => UserDb.get(where: (t) => t.id.equals(authorId)),
  // );
  // return _getauthor!.instance;
  // }

  final _updatedFields = <String, dynamic>{};
  int? id;
  Future<void> save() async {
    if (_updatedFields.isNotEmpty) {
      final query = Query.update(
        table: "book",
        columns: _updatedFields,
        operation: Operation("bookId".safeTk, Operator.eq, id),
      );
      await Database.execute(query.toString());
    }
  }

  Future<bool> delete() async {
    return BookDb.delete(this);
  }

  late String _title;
  String get title => _title;
  set title(String m) {
    _updatedFields['title'] = m;
    _title = m;
  }

  String? _subtitle;
  String? get subtitle => _subtitle;
  set subtitle(String? m) {
    _updatedFields['subtitle'] = m;
    _subtitle = m;
  }
}
