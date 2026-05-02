/// Small string helpers for safe SQL identifier and literal quoting.
library gisila.database.extensions;

extension SafeString on String {
  /// Wrap as a quoted SQL identifier (`"foo"`), idempotent if already
  /// double-quoted at both ends.
  String get safeTk {
    if (length >= 2 && startsWith('"') && endsWith('"')) return this;
    return '"$this"';
  }

  /// Wrap as a single-quoted SQL string literal, idempotent if already
  /// single-quoted at both ends. Inner single quotes are escaped by
  /// doubling per the SQL standard.
  String get safe {
    if (length >= 2 && startsWith("'") && endsWith("'")) return this;
    return "'${replaceAll("'", "''")}'";
  }
}
