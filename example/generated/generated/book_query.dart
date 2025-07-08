part of '../models.dart';

/// Generated query builder for Book model

/// Query builder for Book model
class BookQuery extends Query {
  BookQuery() {
    table = 'book';
    columns = [
      'title',
      'subtitle',
      'description',
      'published_date',
      'isbn',
      'page_count',
    ];
  }

  factory BookQuery.referenced({required List<Join> joins}) =>
      BookQuery().._joins.addAll(joins);

   final table = 'book';

  TextColumn get title => TextColumn(
      column: 'title',
      offtable: 'book',
      depends: _joins);

  TextColumn get subtitle => TextColumn(
      column: 'subtitle',
      offtable: 'book',
      depends: _joins);

  TextColumn get description => TextColumn(
      column: 'description',
      offtable: 'book',
      depends: _joins);

  DateTimeColumn get published_date => DateTimeColumn(
      column: 'published_date',
      offtable: 'book',
      depends: _joins);

  TextColumn get isbn => TextColumn(
      column: 'isbn',
      offtable: 'book',
      depends: _joins);

  NumberColumn get page_count => NumberColumn(
      column: 'page_count',
      offtable: 'book',
      depends: _joins);

  AuthorQuery get author => AuthorQuery.referenced(
      joins: [Join(table: 'author', from: 'book', onn: 'author_id')]);

  final _joins = <Join>[];

   List<String> get columns => <String>[
    'title',
    'subtitle',
    'description',
    'published_date',
    'isbn',
    'page_count',
    'author',
    'reviewers',
  ];

  BookQuery where(Operation operation) {
    return BookQuery()..operation = operation;
  }

  BookQuery select(List<String> columns) {
    return BookQuery()..columns = columns;
  }

}

