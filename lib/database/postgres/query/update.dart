class UpdateQuery {
  final String _table;
  final Map<String, dynamic> _setValues = {};
  final List<String> _whereClauses = [];
  final List<dynamic> _params = [];

  UpdateQuery(this._table);

  UpdateQuery set(Map<String, dynamic> values) {
    _setValues.addAll(values);
    return this;
  }

  UpdateQuery where(String column, String operator, dynamic value) {
    _whereClauses
        .add('$column $operator \$${_params.length + _setValues.length + 1}');
    _params.add(value);
    return this;
  }

  String toSql() {
    if (_setValues.isEmpty) {
      throw Exception('No values provided for UPDATE.');
    }

    final buffer = StringBuffer();
    buffer.write('UPDATE $_table SET ');

    int paramIndex = 1;
    final setClauses = _setValues.entries.map((entry) {
      return '${entry.key} = \$${paramIndex++}';
    }).join(', ');
    buffer.write(setClauses);

    if (_whereClauses.isNotEmpty) {
      buffer.write(' WHERE ${_whereClauses.join(' AND ')}');
    }

    return buffer.toString();
  }

  List<dynamic> get params {
    return [..._setValues.values, ..._params];
  }
}
