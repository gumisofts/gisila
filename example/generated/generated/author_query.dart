part of '../models.dart';

/// Generated query builder for Author model

/// Query builder for Author model
class AuthorQuery extends Query {
  AuthorQuery() {
    table = 'author';
    columns = [
      'id',
      'first_name',
      'last_name',
      'email',
    ];
  }

  factory AuthorQuery.referenced({required List<Join> joins}) =>
      AuthorQuery().._joins.addAll(joins);

   final table = 'author';

  NumberColumn get id => NumberColumn(
      column: 'id',
      offtable: 'author',
      depends: _joins);

  TextColumn get first_name => TextColumn(
      column: 'first_name',
      offtable: 'author',
      depends: _joins);

  TextColumn get last_name => TextColumn(
      column: 'last_name',
      offtable: 'author',
      depends: _joins);

  TextColumn get email => TextColumn(
      column: 'email',
      offtable: 'author',
      depends: _joins);

  final _joins = <Join>[];

   List<String> get columns => <String>[
    'id',
    'first_name',
    'last_name',
    'email',
  ];

  AuthorQuery where(Operation operation) {
    return AuthorQuery()..operation = operation;
  }

  AuthorQuery select(List<String> columns) {
    return AuthorQuery()..columns = columns;
  }

}

