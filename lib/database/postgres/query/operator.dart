enum QueryType {
  select('select'),
  insert('insert'),
  update('update'),
  delete('delete');

  final String type;
  const QueryType(this.type);
}

enum Operator {
  eq('='),
  neq('!='),
  geq('>='),
  ge('>'),
  leq('<='),
  le('<'),
  isNull('isnull'),
  notNull('notnull'),
  between('between'),
  notBetween('not between'),
  like('like'),
  ilike('ilike'),
  inn('in'),
  similar('similar'),
  not('not'),
  and('and'),
  or('or');

  const Operator(this.dbType);
  final String dbType;
  @override
  String toString() => dbType;
}

class Join {
  Join({required this.table, required this.onn, required this.from});
  final String table;
  final String from;
  final String onn;

  @override
  String toString() => 'join $table on $onn';
}

// SELECT [DISTINCT] column_list
// FROM table_name
// [JOIN ...]
// [WHERE condition]
// [GROUP BY column_list]
// [HAVING condition]
// [ORDER BY column_list [ASC|DESC]]
// [LIMIT n]
// [OFFSET m];
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
    return '$leftOp ${op.dbType} $rightOp';
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

class BaseColumn<T> {
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
