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
