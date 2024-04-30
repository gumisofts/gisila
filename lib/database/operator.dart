enum QueryType { select, insert, update, delete }

enum Operator {
  eq,
  neq,
  geq,
  ge,
  leq,
  le,
  isNull,
  notNull,
  between,
  notBetween,
  like,
  ilike,
  inn,
  similar,
  not,
  and,
  or
}

class Join {
  Join({
    required this.table,
    required this.onn,
    required this.from,
  });
  final String table;
  final String from;
  final String onn;

  @override
  String toString() => 'join $table on $onn';
}

class Operation {
  Operation(this.leftOp, this.op, this.rightOp);
  factory Operation.unaryPrefix(Operator op, String right) {
    return Operation('', op, right);
  }
  factory Operation.unaryPostfix(String left, Operator op) {
    return Operation(left, op, '');
  }
  factory Operation.ternary(
    String leftOp,
    dynamic right1,
    Operator op,
    dynamic right2,
  ) {
    return Operation(leftOp, op, '$right1 and $right2');
  }
  final tables = <String>{};

  final joins = <Join>[];

  String leftOp;
  Operator op;
  dynamic rightOp;

  @override
  String toString() {
    return '$leftOp ${dbEquvalentOp(op)} $rightOp';
  }

  Operation operator +(Operation op) {
    return Operation(toString(), Operator.and, op.toString())
      ..joins.addAll([...op.joins, ...joins]);
  }

  Operation operator &(Operation op) {
    if (op == this) return this;
    return Operation('(${toString()})', Operator.and, '($op)')
      ..joins.addAll([...op.joins, ...joins]);
  }

  Operation operator |(Operation op) {
    return Operation('($this)', Operator.or, '($op)')
      ..joins.addAll([...op.joins, ...joins]);
  }

  Operation operator ~() {
    return Operation.unaryPrefix(Operator.not, '($this)')..joins.addAll(joins);
  }
}

String dbEquvalentOp(Operator op) {
  switch (op) {
    case Operator.eq:
      return '=';
    case Operator.neq:
      return '!=';
    case Operator.geq:
      return '>=';
    case Operator.ge:
      return '>';
    case Operator.leq:
      return '<=';
    case Operator.le:
      return '<';
    case Operator.isNull:
      return 'isnull';
    case Operator.notNull:
      return 'notnull';
    case Operator.between:
      return 'between';
    case Operator.like:
      return 'like';
    case Operator.ilike:
      return 'ilike';
    case Operator.inn:
      return 'in';
    case Operator.similar:
      return 'similar';
    case Operator.not:
      return 'not';
    case Operator.and:
      return 'and';
    case Operator.or:
      return 'or';
    case Operator.notBetween:
      return 'not between';
  }
}

abstract class DBColumns {}

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

  // Join? get join =>
  //     from != null ? Join(table: offtable, onn: onColumn!, from: from!) : null;
  // List<Join> get joins => [if (join != null) join!];
  // from != null ? Join(table: offtable, onn: onColumn!, from: from!) : null;

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
