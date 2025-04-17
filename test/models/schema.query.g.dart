part of 'schema.dart';

class UserQuery {
  UserQuery();
  factory UserQuery.referenced({required List<Join> joins}) =>
      UserQuery().._joins.addAll(joins);
  static const table = 'user';
  NumberColumn get id =>
      NumberColumn(column: 'userId', offtable: 'user', depends: _joins);
  TextColumn get name =>
      TextColumn(column: 'name', offtable: 'user', depends: _joins);
  final _joins = <Join>[];
  static List<String> get columns => <String>['userId', 'name'];
}

class BookQuery {
  BookQuery();
  factory BookQuery.referenced({required List<Join> joins}) =>
      BookQuery().._joins.addAll(joins);
  static const table = 'book';
  NumberColumn get id =>
      NumberColumn(column: 'bookId', offtable: 'book', depends: _joins);
  TextColumn get title =>
      TextColumn(column: 'title', offtable: 'book', depends: _joins);
  TextColumn get subtitle =>
      TextColumn(column: 'subtitle', offtable: 'book', depends: _joins);
  UserQuery get author => UserQuery.referenced(
    joins: [..._joins, Join(table: 'user', onn: 'authorId', from: table)],
  );
  NumberColumn get authorId =>
      NumberColumn(column: 'authorId', offtable: 'book', depends: _joins);
  final _joins = <Join>[];
  static List<String> get columns => <String>[
    'bookId',
    'title',
    'subtitle',
    'authorId',
  ];
}
