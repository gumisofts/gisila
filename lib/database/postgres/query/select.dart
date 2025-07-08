import 'package:gisila/database/extensions.dart';
import 'package:gisila/database/postgres/query/operator.dart';

class SelectQuery {
  final List<String> _fields;
  String? _table;
  final List<String> _whereClauses = [];
  final List<dynamic> _params = [];
  String? _orderBy;
  int? _limit;

  SelectQuery(this._fields);

  SelectQuery from(String table) {
    _table = table;
    return this;
  }

  SelectQuery where(String column, String operator, dynamic value) {
    _whereClauses.add('$column $operator \$${_params.length + 1}');
    _params.add(value);
    return this;
  }

  SelectQuery orderBy(String column, {bool descending = false}) {
    _orderBy = '$column ${descending ? 'DESC' : 'ASC'}';
    return this;
  }

  SelectQuery limit(int value) {
    _limit = value;
    return this;
  }

  Joinn join(String table) {
    return Joinn(this, table);
  }

  String toSql() {
    if (_table == null) throw Exception('No table specified.');
    final buffer = StringBuffer();
    buffer.write('SELECT ${_fields.join(', ')} FROM $_table');
    if (_whereClauses.isNotEmpty) {
      buffer.write(' WHERE ${_whereClauses.join(' AND ')}');
    }
    if (_orderBy != null) buffer.write(' ORDER BY $_orderBy');
    if (_limit != null) buffer.write(' LIMIT $_limit');
    return buffer.toString();
  }

  List<dynamic> get params => _params;
}

class Joinn {
  Joinn(this.query, String table);
  SelectQuery query;
  SelectQuery onn(String column, String operator, dynamic value) {
    '${column.safeTk} $operator $value';

    return query;
  }
}

void main() {
  SelectQuery([])
      .where('column', 'operator', 'value')
      .where('column', 'operator', 'value')
      .join('table')
      .onn('column', 'operator', 'value');
}
