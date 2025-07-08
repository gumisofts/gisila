part of '../models.dart';

/// Generated query builder for User model

/// Query builder for User model
class UserQuery extends Query {
  UserQuery() {
    table = 'user';
    columns = [
      'id',
      'first_name',
      'last_name',
      'email',
      'password',
      'date_joined',
    ];
  }

  factory UserQuery.referenced({required List<Join> joins}) =>
      UserQuery().._joins.addAll(joins);

   final table = 'user';

  NumberColumn get id => NumberColumn(
      column: 'id',
      offtable: 'user',
      depends: _joins);

  TextColumn get first_name => TextColumn(
      column: 'first_name',
      offtable: 'user',
      depends: _joins);

  TextColumn get last_name => TextColumn(
      column: 'last_name',
      offtable: 'user',
      depends: _joins);

  TextColumn get email => TextColumn(
      column: 'email',
      offtable: 'user',
      depends: _joins);

  TextColumn get password => TextColumn(
      column: 'password',
      offtable: 'user',
      depends: _joins);

  DateTimeColumn get date_joined => DateTimeColumn(
      column: 'date_joined',
      offtable: 'user',
      depends: _joins);

  final _joins = <Join>[];

   List<String> get columns => <String>[
    'id',
    'first_name',
    'last_name',
    'email',
    'password',
    'date_joined',
  ];

  UserQuery where(Operation operation) {
    return UserQuery()..operation = operation;
  }

  UserQuery select(List<String> columns) {
    return UserQuery()..columns = columns;
  }

}

