/// Example usage of Gisila Migration System
///
/// This example demonstrates how to:
/// - Set up migration manager
/// - Apply and rollback migrations
/// - Compare schemas and generate migrations
/// - Handle migration errors and edge cases

import 'dart:async';
import 'dart:io';
import 'package:pg_dorm/config/config.dart';
import 'package:pg_dorm/migrations/migrations.dart';
import 'package:pg_dorm/generators/generators.dart';

void main() async {
  print('🚀 Gisila Migration System Example');
  print('');

  try {
    // Example 1: Basic Migration Management
    await example1_basicMigrations();

    print('');
    print('─' * 60);
    print('');

    // Example 2: Schema Comparison and Generation
    await example2_schemaComparison();

    print('');
    print('─' * 60);
    print('');

    // Example 3: Advanced Migration Operations
    await example3_advancedOperations();

    print('');
    print('─' * 60);
    print('');

    // Example 4: Error Handling and Recovery
    await example4_errorHandling();
  } catch (e) {
    print('❌ Example failed: $e');
  }
}

/// Example 1: Basic migration management
Future<void> example1_basicMigrations() async {
  print('📖 Example 1: Basic Migration Management');
  print('');

  // Create database configuration
  final dbConfig = DatabaseConfig.programmatic({
    'primary': DatabaseConnection(
      type: DatabaseType.sqlite,
      database: 'example.db',
    ),
  });

  // Initialize migration manager
  final manager = MigrationManager(dbConfig, 'example/migrations');

  try {
    // Initialize migration system
    print('🏗️  Initializing migration system...');
    await manager.initialize();
    print('✅ Migration system initialized');

    // Check migration status
    print('');
    print('📋 Checking migration status...');
    await manager.status();

    // Apply pending migrations
    print('');
    print('🔄 Applying pending migrations...');
    final options = MigrationOptions(
      verbose: true,
      dryRun: false,
      createBackup: true,
    );

    final results = await manager.migrate(options: options);

    if (results.isNotEmpty) {
      print('📊 Applied ${results.length} migrations');
      for (final result in results) {
        if (result.success) {
          print(
              '  ✅ ${result.migrationId} (${result.duration.inMilliseconds}ms)');
        } else {
          print('  ❌ ${result.migrationId}: ${result.error}');
        }
      }
    } else {
      print('✅ No pending migrations');
    }
  } catch (e) {
    print('❌ Migration failed: $e');
  }
}

/// Example 2: Schema comparison and migration generation
Future<void> example2_schemaComparison() async {
  print('📖 Example 2: Schema Comparison and Migration Generation');
  print('');

  // Create old schema
  final oldSchemaYaml = '''
User:
  columns:
    first_name:
      type: varchar
      is_null: false
    email:
      type: varchar
      is_null: false
      is_unique: true
''';

  // Create new schema with changes
  final newSchemaYaml = '''
User:
  columns:
    first_name:
      type: varchar
      is_null: false
    last_name:
      type: varchar
      is_null: true
    email:
      type: varchar
      is_null: false
      is_unique: true
    created_at:
      type: timestamp
      is_null: false

Post:
  columns:
    title:
      type: varchar
      is_null: false
    content:
      type: text
      is_null: true
    author:
      type: User
      references: User
      is_index: true
''';

  try {
    // Parse schemas
    print('🔍 Parsing schemas...');
    final oldSchema = SchemaDefinition.fromYaml(oldSchemaYaml);
    final newSchema = SchemaDefinition.fromYaml(newSchemaYaml);

    // Compare schemas
    print('📊 Comparing schemas...');
    final differ = SchemaDiffer();
    final diff = differ.compareSchemas(oldSchema, newSchema);

    if (diff.isEmpty) {
      print('✅ No differences found');
      return;
    }

    print('📦 Found ${diff.changes.length} changes:');
    for (final change in diff.changes) {
      final icon = diff.hasDestructiveChanges ? '⚠️ ' : '✅ ';
      print('  $icon$change');
    }

    if (diff.hasDestructiveChanges) {
      print('');
      print('⚠️  WARNING: Destructive changes detected!');
    }

    // Generate migration files
    print('');
    print('📝 Generating migration files...');
    await Directory('example/generated_migrations').create(recursive: true);
    await differ.generateMigrationFile(
        diff, 'example/generated_migrations', 'update_user_schema');
  } catch (e) {
    print('❌ Schema comparison failed: $e');
  }
}

/// Example 3: Advanced migration operations
Future<void> example3_advancedOperations() async {
  print('📖 Example 3: Advanced Migration Operations');
  print('');

  final dbConfig = DatabaseConfig.programmatic({
    'primary': DatabaseConnection(
      type: DatabaseType.sqlite,
      database: 'advanced_example.db',
    ),
  });

  final manager = MigrationManager(dbConfig, 'example/migrations');

  try {
    await manager.initialize();

    // Dry run migration
    print('🔍 Performing dry run migration...');
    final dryRunOptions = MigrationOptions(
      dryRun: true,
      verbose: true,
    );

    final dryRunResults = await manager.migrate(options: dryRunOptions);
    print(
        '📊 Dry run completed: ${dryRunResults.length} migrations would be applied');

    // Apply migrations with backup
    print('');
    print('💾 Applying migrations with backup...');
    final backupOptions = MigrationOptions(
      createBackup: true,
      verbose: true,
    );

    await manager.migrate(options: backupOptions);

    // Get applied migrations
    print('');
    print('📋 Getting applied migrations...');
    final applied = await manager.getAppliedMigrations();
    print('Applied migrations: ${applied.length}');
    for (final migration in applied) {
      print('  - $migration');
    }

    // Rollback specific number of migrations
    print('');
    print('⏪ Rolling back last 2 migrations...');
    final rollbackResults = await manager.rollback(
      steps: 2,
      options: MigrationOptions(verbose: true),
    );

    print(
        '📊 Rollback completed: ${rollbackResults.length} migrations rolled back');
  } catch (e) {
    print('❌ Advanced operations failed: $e');
  }
}

/// Example 4: Error handling and recovery
Future<void> example4_errorHandling() async {
  print('📖 Example 4: Error Handling and Recovery');
  print('');

  final dbConfig = DatabaseConfig.programmatic({
    'primary': DatabaseConnection(
      type: DatabaseType.sqlite,
      database: 'error_example.db',
    ),
  });

  final manager = MigrationManager(dbConfig, 'example/migrations');

  try {
    await manager.initialize();

    // Example: Force continue on errors
    print('🔧 Testing force continue on errors...');
    final forceOptions = MigrationOptions(
      force: true,
      verbose: true,
    );

    final results = await manager.migrate(options: forceOptions);

    // Check for any failures
    final failures = results.where((r) => !r.success).toList();
    if (failures.isNotEmpty) {
      print(
          '⚠️  ${failures.length} migrations failed but continued due to force flag:');
      for (final failure in failures) {
        print('  ❌ ${failure.migrationId}: ${failure.error}');
      }
    }

    // Example: Handle migration rollback on failure
    print('');
    print('🔄 Testing rollback on failure...');
    try {
      // This would normally stop on first failure
      await manager.migrate(options: MigrationOptions(verbose: true));
    } catch (e) {
      print('❌ Migration failed: $e');
      print('🔄 Attempting rollback...');

      try {
        await manager.rollback(
          steps: 1,
          options: MigrationOptions(verbose: true),
        );
        print('✅ Rollback successful');
      } catch (rollbackError) {
        print('❌ Rollback also failed: $rollbackError');
      }
    }
  } catch (e) {
    print('❌ Error handling example failed: $e');
  }
}

/// Helper: Create sample migration files for testing
Future<void> createSampleMigrations() async {
  final migrationsDir = Directory('example/migrations');
  await migrationsDir.create(recursive: true);

  // Create sample migration
  final timestamp = DateTime.now().millisecondsSinceEpoch;

  final upFile = File('example/migrations/${timestamp}_create_users.sql');
  final downFile =
      File('example/migrations/${timestamp}_create_users.down.sql');

  await upFile.writeAsString('''
-- Migration: create_users
-- Generated on: ${DateTime.now().toIso8601String()}

BEGIN;

CREATE TABLE users (
  id INTEGER PRIMARY KEY NOT NULL,
  first_name VARCHAR(255) NOT NULL,
  email VARCHAR(255) NOT NULL UNIQUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_email ON users (email);

COMMIT;
''');

  await downFile.writeAsString('''
-- Down migration: create_users
-- Generated on: ${DateTime.now().toIso8601String()}

BEGIN;

DROP INDEX IF EXISTS idx_users_email;
DROP TABLE IF EXISTS users;

COMMIT;
''');

  print('📝 Created sample migration files');
}
