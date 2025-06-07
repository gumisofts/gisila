/// Schema differ for Gisila ORM
/// Compares schemas and generates migration operations

import 'dart:async';
import 'dart:io';
import '../generators/schema_parser.dart';

/// Types of schema changes
enum ChangeType {
  createTable,
  dropTable,
  renameTable,
  addColumn,
  dropColumn,
  modifyColumn,
  renameColumn,
  addIndex,
  dropIndex,
  addForeignKey,
  dropForeignKey,
}

/// Represents a single schema change
class SchemaChange {
  final ChangeType type;
  final String? tableName;
  final String? columnName;
  final String? oldName;
  final String? newName;
  final Map<String, dynamic>? metadata;

  const SchemaChange({
    required this.type,
    this.tableName,
    this.columnName,
    this.oldName,
    this.newName,
    this.metadata,
  });

  @override
  String toString() {
    switch (type) {
      case ChangeType.createTable:
        return 'Create table: $tableName';
      case ChangeType.dropTable:
        return 'Drop table: $tableName';
      case ChangeType.renameTable:
        return 'Rename table: $oldName → $newName';
      case ChangeType.addColumn:
        return 'Add column: $tableName.$columnName';
      case ChangeType.dropColumn:
        return 'Drop column: $tableName.$columnName';
      case ChangeType.modifyColumn:
        return 'Modify column: $tableName.$columnName';
      case ChangeType.renameColumn:
        return 'Rename column: $tableName.$oldName → $newName';
      case ChangeType.addIndex:
        return 'Add index: $tableName';
      case ChangeType.dropIndex:
        return 'Drop index: $tableName';
      case ChangeType.addForeignKey:
        return 'Add foreign key: $tableName.$columnName';
      case ChangeType.dropForeignKey:
        return 'Drop foreign key: $tableName.$columnName';
    }
  }
}

/// Migration operation
class MigrationOperation {
  final String upSql;
  final String downSql;
  final SchemaChange change;

  const MigrationOperation({
    required this.upSql,
    required this.downSql,
    required this.change,
  });
}

/// Schema comparison result
class SchemaDiff {
  final List<SchemaChange> changes;
  final List<MigrationOperation> operations;
  final bool hasDestructiveChanges;

  const SchemaDiff({
    required this.changes,
    required this.operations,
    required this.hasDestructiveChanges,
  });

  bool get isEmpty => changes.isEmpty;
  bool get isNotEmpty => changes.isNotEmpty;
}

/// Schema differ class
class SchemaDiffer {
  /// Compare two schemas and generate diff
  SchemaDiff compareSchemas(
      SchemaDefinition oldSchema, SchemaDefinition newSchema) {
    final changes = <SchemaChange>[];
    final operations = <MigrationOperation>[];

    // Build lookup maps
    final oldModels = <String, ModelDefinition>{};
    final newModels = <String, ModelDefinition>{};

    for (final model in oldSchema.models) {
      oldModels[model.name] = model;
    }

    for (final model in newSchema.models) {
      newModels[model.name] = model;
    }

    // Find table changes
    _compareModels(oldModels, newModels, changes, operations);

    // Check for destructive changes
    final hasDestructive = changes.any((change) =>
        change.type == ChangeType.dropTable ||
        change.type == ChangeType.dropColumn ||
        change.type == ChangeType.modifyColumn);

    return SchemaDiff(
      changes: changes,
      operations: operations,
      hasDestructiveChanges: hasDestructive,
    );
  }

  /// Compare models (tables)
  void _compareModels(
    Map<String, ModelDefinition> oldModels,
    Map<String, ModelDefinition> newModels,
    List<SchemaChange> changes,
    List<MigrationOperation> operations,
  ) {
    // Dropped tables
    for (final oldModel in oldModels.values) {
      if (!newModels.containsKey(oldModel.name)) {
        final change = SchemaChange(
          type: ChangeType.dropTable,
          tableName: oldModel.tableName,
        );
        changes.add(change);
        operations.add(_generateDropTableOperation(oldModel, change));
      }
    }

    // New tables
    for (final newModel in newModels.values) {
      if (!oldModels.containsKey(newModel.name)) {
        final change = SchemaChange(
          type: ChangeType.createTable,
          tableName: newModel.tableName,
        );
        changes.add(change);
        operations.add(_generateCreateTableOperation(newModel, change));
      }
    }

    // Modified tables
    for (final newModel in newModels.values) {
      final oldModel = oldModels[newModel.name];
      if (oldModel != null) {
        // Check for table rename
        if (oldModel.tableName != newModel.tableName) {
          final change = SchemaChange(
            type: ChangeType.renameTable,
            oldName: oldModel.tableName,
            newName: newModel.tableName,
          );
          changes.add(change);
          operations
              .add(_generateRenameTableOperation(oldModel, newModel, change));
        }

        // Compare columns
        _compareColumns(oldModel, newModel, changes, operations);

        // Compare indexes
        _compareIndexes(oldModel, newModel, changes, operations);
      }
    }
  }

  /// Compare columns
  void _compareColumns(
    ModelDefinition oldModel,
    ModelDefinition newModel,
    List<SchemaChange> changes,
    List<MigrationOperation> operations,
  ) {
    final oldColumns = <String, ColumnDefinition>{};
    final newColumns = <String, ColumnDefinition>{};

    for (final col in oldModel.columns) {
      oldColumns[col.name] = col;
    }

    for (final col in newModel.columns) {
      newColumns[col.name] = col;
    }

    // Dropped columns
    for (final oldCol in oldColumns.values) {
      if (!newColumns.containsKey(oldCol.name)) {
        final change = SchemaChange(
          type: ChangeType.dropColumn,
          tableName: newModel.tableName,
          columnName: oldCol.name,
        );
        changes.add(change);
        operations.add(_generateDropColumnOperation(newModel, oldCol, change));
      }
    }

    // New columns
    for (final newCol in newColumns.values) {
      if (!oldColumns.containsKey(newCol.name)) {
        final change = SchemaChange(
          type: ChangeType.addColumn,
          tableName: newModel.tableName,
          columnName: newCol.name,
        );
        changes.add(change);
        operations.add(_generateAddColumnOperation(newModel, newCol, change));
      }
    }

    // Modified columns
    for (final newCol in newColumns.values) {
      final oldCol = oldColumns[newCol.name];
      if (oldCol != null && _isColumnModified(oldCol, newCol)) {
        final change = SchemaChange(
          type: ChangeType.modifyColumn,
          tableName: newModel.tableName,
          columnName: newCol.name,
          metadata: {
            'oldColumn': oldCol,
            'newColumn': newCol,
          },
        );
        changes.add(change);
        operations.add(
            _generateModifyColumnOperation(newModel, oldCol, newCol, change));
      }
    }
  }

  /// Compare indexes
  void _compareIndexes(
    ModelDefinition oldModel,
    ModelDefinition newModel,
    List<SchemaChange> changes,
    List<MigrationOperation> operations,
  ) {
    final oldIndexes = <String, IndexDefinition>{};
    final newIndexes = <String, IndexDefinition>{};

    for (final idx in oldModel.indexes) {
      oldIndexes[idx.name] = idx;
    }

    for (final idx in newModel.indexes) {
      newIndexes[idx.name] = idx;
    }

    // Dropped indexes
    for (final oldIdx in oldIndexes.values) {
      if (!newIndexes.containsKey(oldIdx.name)) {
        final change = SchemaChange(
          type: ChangeType.dropIndex,
          tableName: newModel.tableName,
          columnName: oldIdx.name,
        );
        changes.add(change);
        operations.add(_generateDropIndexOperation(newModel, oldIdx, change));
      }
    }

    // New indexes
    for (final newIdx in newIndexes.values) {
      if (!oldIndexes.containsKey(newIdx.name)) {
        final change = SchemaChange(
          type: ChangeType.addIndex,
          tableName: newModel.tableName,
          columnName: newIdx.name,
        );
        changes.add(change);
        operations.add(_generateAddIndexOperation(newModel, newIdx, change));
      }
    }
  }

  /// Check if column is modified
  bool _isColumnModified(ColumnDefinition oldCol, ColumnDefinition newCol) {
    return oldCol.type != newCol.type ||
        oldCol.constraints.isNull != newCol.constraints.isNull ||
        oldCol.constraints.isUnique != newCol.constraints.isUnique ||
        oldCol.constraints.isPrimary != newCol.constraints.isPrimary ||
        oldCol.constraints.defaultValue != newCol.constraints.defaultValue;
  }

  // Migration operation generators

  MigrationOperation _generateCreateTableOperation(
      ModelDefinition model, SchemaChange change) {
    final upSql = _generateCreateTableSql(model);
    final downSql = 'DROP TABLE IF EXISTS ${model.tableName};';

    return MigrationOperation(
      upSql: upSql,
      downSql: downSql,
      change: change,
    );
  }

  MigrationOperation _generateDropTableOperation(
      ModelDefinition model, SchemaChange change) {
    final upSql = 'DROP TABLE IF EXISTS ${model.tableName};';
    final downSql = _generateCreateTableSql(model);

    return MigrationOperation(
      upSql: upSql,
      downSql: downSql,
      change: change,
    );
  }

  MigrationOperation _generateRenameTableOperation(
      ModelDefinition oldModel, ModelDefinition newModel, SchemaChange change) {
    final upSql =
        'ALTER TABLE ${oldModel.tableName} RENAME TO ${newModel.tableName};';
    final downSql =
        'ALTER TABLE ${newModel.tableName} RENAME TO ${oldModel.tableName};';

    return MigrationOperation(
      upSql: upSql,
      downSql: downSql,
      change: change,
    );
  }

  MigrationOperation _generateAddColumnOperation(
      ModelDefinition model, ColumnDefinition column, SchemaChange change) {
    final columnDef = _generateColumnDefinition(column);
    final upSql = 'ALTER TABLE ${model.tableName} ADD COLUMN $columnDef;';
    final downSql =
        'ALTER TABLE ${model.tableName} DROP COLUMN ${column.name};';

    return MigrationOperation(
      upSql: upSql,
      downSql: downSql,
      change: change,
    );
  }

  MigrationOperation _generateDropColumnOperation(
      ModelDefinition model, ColumnDefinition column, SchemaChange change) {
    final columnDef = _generateColumnDefinition(column);
    final upSql = 'ALTER TABLE ${model.tableName} DROP COLUMN ${column.name};';
    final downSql = 'ALTER TABLE ${model.tableName} ADD COLUMN $columnDef;';

    return MigrationOperation(
      upSql: upSql,
      downSql: downSql,
      change: change,
    );
  }

  MigrationOperation _generateModifyColumnOperation(
    ModelDefinition model,
    ColumnDefinition oldColumn,
    ColumnDefinition newColumn,
    SchemaChange change,
  ) {
    final newDef = _generateColumnDefinition(newColumn);
    final oldDef = _generateColumnDefinition(oldColumn);

    // PostgreSQL style
    final upSql =
        'ALTER TABLE ${model.tableName} ALTER COLUMN ${newColumn.name} TYPE ${newColumn.postgresType};';
    final downSql =
        'ALTER TABLE ${model.tableName} ALTER COLUMN ${oldColumn.name} TYPE ${oldColumn.postgresType};';

    return MigrationOperation(
      upSql: upSql,
      downSql: downSql,
      change: change,
    );
  }

  MigrationOperation _generateAddIndexOperation(
      ModelDefinition model, IndexDefinition index, SchemaChange change) {
    final uniqueStr = index.isUnique ? 'UNIQUE ' : '';
    final columnsStr = index.columns.join(', ');
    final upSql =
        'CREATE ${uniqueStr}INDEX ${index.name} ON ${model.tableName} ($columnsStr);';
    final downSql = 'DROP INDEX IF EXISTS ${index.name};';

    return MigrationOperation(
      upSql: upSql,
      downSql: downSql,
      change: change,
    );
  }

  MigrationOperation _generateDropIndexOperation(
      ModelDefinition model, IndexDefinition index, SchemaChange change) {
    final uniqueStr = index.isUnique ? 'UNIQUE ' : '';
    final columnsStr = index.columns.join(', ');
    final upSql = 'DROP INDEX IF EXISTS ${index.name};';
    final downSql =
        'CREATE ${uniqueStr}INDEX ${index.name} ON ${model.tableName} ($columnsStr);';

    return MigrationOperation(
      upSql: upSql,
      downSql: downSql,
      change: change,
    );
  }

  /// Generate complete CREATE TABLE SQL
  String _generateCreateTableSql(ModelDefinition model) {
    final buffer = StringBuffer();
    buffer.writeln('CREATE TABLE ${model.tableName} (');

    final columnDefs = <String>[];
    for (final column in model.columns) {
      if (!column.isRelationship || column.type == ColumnType.foreignKey) {
        columnDefs.add('  ${_generateColumnDefinition(column)}');
      }
    }

    buffer.writeln(columnDefs.join(',\n'));
    buffer.write(');');

    return buffer.toString();
  }

  /// Generate column definition SQL
  String _generateColumnDefinition(ColumnDefinition column) {
    final buffer = StringBuffer();

    if (column.type == ColumnType.foreignKey) {
      buffer.write('${column.name}_id ${column.postgresType}');
    } else {
      buffer.write('${column.name} ${column.postgresType}');
    }

    if (column.constraints.isPrimary) {
      buffer.write(' PRIMARY KEY');
    }

    if (!column.constraints.isNull) {
      buffer.write(' NOT NULL');
    }

    if (column.constraints.isUnique && !column.constraints.isPrimary) {
      buffer.write(' UNIQUE');
    }

    if (column.constraints.defaultValue != null) {
      buffer.write(' DEFAULT ${column.constraints.defaultValue}');
    }

    return buffer.toString();
  }

  /// Generate migration file from diff
  Future<void> generateMigrationFile(
      SchemaDiff diff, String outputPath, String migrationName) async {
    if (diff.isEmpty) {
      throw ArgumentError('No changes to generate migration for');
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final upFile = File('$outputPath/${timestamp}_$migrationName.sql');
    final downFile = File('$outputPath/${timestamp}_$migrationName.down.sql');

    // Create output directory
    await Directory(outputPath).create(recursive: true);

    // Generate up migration
    final upBuffer = StringBuffer();
    upBuffer.writeln('-- Migration: $migrationName');
    upBuffer.writeln('-- Generated on: ${DateTime.now().toIso8601String()}');
    upBuffer.writeln();
    upBuffer.writeln('BEGIN;');
    upBuffer.writeln();

    for (final operation in diff.operations) {
      upBuffer.writeln('-- ${operation.change}');
      upBuffer.writeln(operation.upSql);
      upBuffer.writeln();
    }

    upBuffer.writeln('COMMIT;');

    // Generate down migration
    final downBuffer = StringBuffer();
    downBuffer.writeln('-- Down migration: $migrationName');
    downBuffer.writeln('-- Generated on: ${DateTime.now().toIso8601String()}');
    downBuffer.writeln();
    downBuffer.writeln('BEGIN;');
    downBuffer.writeln();

    // Reverse order for down migration
    for (final operation in diff.operations.reversed) {
      downBuffer.writeln('-- Rollback: ${operation.change}');
      downBuffer.writeln(operation.downSql);
      downBuffer.writeln();
    }

    downBuffer.writeln('COMMIT;');

    // Write files
    await upFile.writeAsString(upBuffer.toString());
    await downFile.writeAsString(downBuffer.toString());

    print('✅ Generated migration files:');
    print('   Up:   ${upFile.path}');
    print('   Down: ${downFile.path}');
  }
}
