/// Gisila migration system entry point.
///
/// Re-exports the [SchemaDiffer] (for diffing two schema versions and
/// emitting up/down SQL). The [MigrationManager] runtime executor lives
/// in [migration_manager.dart] and is also re-exported here.
library gisila.migrations;

export 'migration_manager.dart';
export 'schema_differ.dart';
