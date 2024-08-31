import 'package:pg_dorm/database/extensions.dart';
import 'package:pg_dorm/database/operator.dart';

final class Query {
  Query();
  factory Query.select({
    required String table,
    required List<String> columns,
    Operation? operation,
    List<Join> joins = const [],
    int offset = 0,
    int? limit,
  }) {
    return Query()
      ..table = table
      ..columns = columns
      ..operation = operation
      ..queryType = QueryType.select
      ..joins = joins
      .._offset = offset
      .._limit = limit;
  }
  factory Query.insert({
    required String table,
    required Map<String, dynamic> columns,
  }) {
    // columns.removeWhere((key, value) {
    //   if (value == null) {
    //     return MapEntry(key, value);
    //   }
    // });

    columns
      ..removeWhere((key, value) => value == null)
      ..remove('id');
    final cols = columns.keys.toList();
    final values = columns.values.toList();
    return Query()
      ..table = table
      ..columns = cols
      ..queryType = QueryType.insert
      ..values = values;
  }
  factory Query.update({
    required String table,
    required Map<String, dynamic> columns,
    required Operation operation,
  }) {
    final cols = columns.keys.toList();
    final values = columns.values.toList();
    return Query()
      ..table = table
      ..columns = cols
      ..values = values
      ..queryType = QueryType.update
      ..operation = operation;
  }
  factory Query.delete({
    required String table,
    required Operation operation,
  }) {
    return Query()
      ..table = table
      ..queryType = QueryType.delete
      ..operation = operation;
  }

  String? table;
  QueryType? queryType;
  List<String>? columns;
  List<dynamic>? values;
  int _offset = 0;
  int? _limit;

  List<Join>? joins;
  List<String> _orderBy = [];
  Operation? operation;

  String count() =>
      "select count(*) from ${table!.safeTk} ${operation != null ? 'where $operation' : ''}";

  @override
  String toString() {
    if (queryType case QueryType.delete) {
      return '''delete from ${table!.safeTk} where $operation returning * ;''';
    }
    if (queryType case QueryType.insert) {
      final vals = values!.map((v) => v.toString().safe);
      final cols = columns!.map((v) => v.safeTk);
      return '''insert into ${table!.safeTk} (${cols.join(',')}) Values(${vals.join(',')}) returning *;''';
    }
    if (queryType case QueryType.update) {
      final data = <String>[];
      for (var i = 0; i < columns!.length; i++) {
        data.add("${columns![i].safeTk}='${values![i]}'");
      }
      return '''update ${table!.safeTk} set ${data.join(',')} where $operation returning *;''';
    }

    final selections =
        columns!.map((e) => '${table!.safeTk}.${e.safeTk}').toList().join(',');
    joins ??= [];

    final join = joins!
        .map(
          (e) =>
              'Join "${e.table}" on "${e.from}"."${e.onn}"="${e.table}"."${e.table}Id"',
        )
        .join(' ');

    return '''select $selections from ${table!.safeTk} $join ${operation != null ? 'where $operation' : ''} limit ${_limit ?? 'all'} ${_orderBy.join(',')} offset $_offset ;''';
  }

  Query operator &(Query query) {
    if (operation == null) {
      return copy()..operation = query.operation;
    }
    if (query.operation == null) {
      return copy()..operation = operation;
    }
    return copy()..operation = operation! & query.operation!;
  }

  Query operator |(Query query) {
    if (operation == null) {
      return copy()..operation = query.operation;
    }
    if (query.operation == null) {
      return copy()..operation = operation;
    }
    return copy()..operation = operation! | query.operation!;
  }

  Query operator ~() {
    return copy()..operation = ~operation!;
  }

  Query limit(int limit) {
    return copy().._limit = limit;
  }

  Query offset(int offset) {
    return copy().._offset = offset;
  }

  Query orderBy(String field) {
    return copy().._orderBy = [..._orderBy, field];
  }

  Query copy() {
    return Query()
      ..table = table
      ..columns = columns
      ..values = values
      ..joins = joins
      ..operation = operation
      .._orderBy = _orderBy
      .._offset = _offset
      .._limit = _limit;
  }

  Query copyWithCondition(Operation operation) {
    return Query()
      ..table = table
      ..columns = columns
      ..values = values
      ..joins = joins
      ..operation = operation
      .._orderBy = _orderBy
      .._offset = _offset
      .._limit = _limit;
  }
}
