import 'package:gisila/database/extensions.dart';
import 'package:gisila/database/postgres/query/operator.dart';

class Query {
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
  factory Query.delete({required String table, required Operation operation}) {
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

abstract class BaseColumn<T> {
  BaseColumn({
    required this.column,
    required this.offtable,
    List<Join> depends = const [],
  }) {
    _joins = depends;
  }
  String column;
  String offtable;
  List<Join> _joins = const [];
  String? from;
  String? onColumn;

  Operation equals(T other) {
    late Operation op;
    if (other is String) {
      final value = "'$other'";
      op = Operation(toString(), Operator.eq, value);
    } else {
      op = Operation(toString(), Operator.eq, other);
    }

    return op..joins.addAll(_joins);
  }

  Operation notEquals(T other) {
    return Operation(toString(), Operator.neq, other);
  }

  Operation isNull(T other) {
    return Operation.unaryPostfix(toString(), Operator.isNull);
  }

  Operation isNotNull(T other) {
    return Operation.unaryPostfix(toString(), Operator.notNull);
  }

  Operation inn(List<T> others) {
    return Operation(toString(), Operator.inn, others);
  }

  @override
  String toString() => '"$offtable"."$column"';
}

class TextColumn extends BaseColumn<String> {
  TextColumn({required super.column, required super.offtable, super.depends});

  Operation operator >=(String other) =>
      Operation(toString(), Operator.geq, other)..tables.add(offtable);

  Operation operator <=(String other) =>
      Operation(toString(), Operator.leq, other)..tables.add(offtable);

  Operation operator >(String other) =>
      Operation(toString(), Operator.ge, other)..tables.add(offtable);

  Operation operator <(String other) =>
      Operation(toString(), Operator.le, other)..tables.add(offtable);
  Operation ilike(String other) =>
      Operation(toString(), Operator.ilike, other)..tables.add(offtable);
  Operation like(String other) =>
      Operation(toString(), Operator.like, other)..tables.add(offtable);
  Operation contains(String other) =>
      Operation(toString(), Operator.like, other)..tables.add(offtable);
  Operation icontains(String other) =>
      Operation(toString(), Operator.like, other)..tables.add(offtable);
}

class NumberColumn<T extends num> extends BaseColumn<T> {
  NumberColumn({required super.column, required super.offtable, super.depends});

  Operation operator >=(String other) =>
      Operation(toString(), Operator.geq, other)..tables.add(offtable);

  Operation operator <=(String other) =>
      Operation(toString(), Operator.leq, other)..tables.add(offtable);

  Operation operator >(String other) =>
      Operation(toString(), Operator.ge, other)..tables.add(offtable);

  Operation operator <(String other) =>
      Operation(toString(), Operator.le, other)..tables.add(offtable);

  Operation inRange(T first, T last) {
    return Operation(toString(), Operator.between, last)..tables.add(offtable);
  }
}

class BooleanColumn extends BaseColumn<bool> {
  // BooleanColumn({required super.column, required super.offtable});
  BooleanColumn(
      {required super.column, required super.offtable, super.depends});
}

class DateTimeColumn extends BaseColumn<DateTime> {
  // DateTimeColumn({required super.column, required super.offtable});
  DateTimeColumn(
      {required super.column, required super.offtable, super.depends});
}

class BaseDbQuery {
  Operation operation;
  BaseDbQuery(this.operation);
}
