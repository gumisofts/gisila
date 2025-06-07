class InsertQuery {
  final String _table;
  final List<Map<String, dynamic>> _rows = [];

  InsertQuery(this._table);

  InsertQuery values(Map<String, dynamic> row) {
    _rows.add(row);
    return this;
  }

  String toSql() {
    if (_rows.isEmpty) {
      throw Exception('No values provided for INSERT.');
    }

    final columns = _rows.first.keys.toList();
    final columnList = columns.join(', ');

    final buffer = StringBuffer();
    buffer.write('INSERT INTO $_table ($columnList) VALUES ');

    int paramIndex = 1;
    final valueStrings = _rows.map((row) {
      final placeholders = row.entries.map((_) => '\$${paramIndex++}').toList();
      return '(${placeholders.join(', ')})';
    }).join(', ');

    buffer.write(valueStrings);
    return buffer.toString();
  }

  List<dynamic> get params {
    return _rows.expand((row) => row.values).toList();
  }

  @override
  String toString() => toSql();
}
