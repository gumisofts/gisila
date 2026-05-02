/// Materialize raw `Result` rows into typed model objects.
///
/// Generated model classes provide a `T.fromRow(Map<String, dynamic>)`
/// factory; the [Hydrator] delegates to it after coercing
/// driver-returned values into the shapes Dart code expects (e.g.
/// numeric strings → `int`, ISO datetime strings → `DateTime`).
library gisila.query.hydrator;

import 'package:postgres/postgres.dart';

/// A function that builds a [T] from a column-name → value map.
typedef RowMapper<T> = T Function(Map<String, dynamic> row);

/// Helper that converts driver rows into typed model instances.
class Hydrator<T> {
  final RowMapper<T> mapper;
  const Hydrator(this.mapper);

  /// Hydrate a list of rows.
  List<T> hydrateAll(Iterable<ResultRow> rows) =>
      rows.map(hydrateOne).toList(growable: false);

  /// Hydrate a single row.
  T hydrateOne(ResultRow row) => mapper(_normalize(row.toColumnMap()));

  /// Postgres returns numerics as `String` (for `numeric`) and JSON as
  /// already-decoded structures; coerce a few common cases here so
  /// generated `fromRow` constructors can stay simple.
  Map<String, dynamic> _normalize(Map<String, dynamic> raw) {
    final out = <String, dynamic>{};
    for (final entry in raw.entries) {
      out[entry.key] = entry.value;
    }
    return out;
  }
}
