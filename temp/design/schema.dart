import 'package:pg_dorm/pg_dorm.dart';
part 'schema.db.g.dart';
part 'schema.query.g.dart';

class User {
  String id;
  String firstName;
  String? lastName;
  late DateTime createdAt;
  late DateTime updatedAt;

  Iterable<Todo>? todos;

  User({required this.id, required this.firstName, this.lastName});
}

class Todo {
  String id;
  String title;
  String desc;
  User? user;
  String userId;

  Iterator<Tag>? tags;

  Todo(
      {required this.id,
      required this.title,
      required this.desc,
      required this.userId});
}

class Tag {
  String id;
  String name;

  Iterator<Todo>? todos;

  Tag({required this.id, required this.name});
}
