/// Gisila ORM Migration System
/// 
/// Provides comprehensive database migration capabilities including:
/// - Migration file management and execution
/// - Schema comparison and diff generation
/// - Safe rollback operations
/// - Transactional migration execution
/// - Multi-database support
/// 
/// ## Features
/// 
/// ### Migration Manager
/// - Apply pending migrations with transaction safety
/// - Rollback migrations with configurable steps
/// - Track migration state in dedicated table
/// - Support for dry-run mode
/// - Automatic backup creation
/// - Multi-connection support
/// 
/// ### Schema Differ
/// - Compare schema definitions and detect changes
/// - Generate migration operations automatically
/// - Support for table, column, and index changes
/// - Identify destructive changes
/// - Generate SQL for up/down migrations
/// 
/// ### CLI Tools
/// - Comprehensive command-line interface
/// - Migration generation from schema diffs
/// - Status reporting and validation
/// - Interactive migration management
/// 
/// ## Usage
/// 
/// ### Basic Migration Management
/// ```dart
/// import 'package:pg_dorm/migrations/migrations.dart';
/// import 'package:pg_dorm/config/config.dart';
/// 
/// // Initialize migration manager
/// final dbConfig = await DatabaseConfig.fromFile('database.yaml');
/// final manager = MigrationManager(dbConfig, 'migrations/');
/// 
/// await manager.initialize();
/// 
/// // Apply pending migrations
/// final options = MigrationOptions(verbose: true);
/// final results = await manager.migrate(options: options);
/// 
/// // Check migration status
/// await manager.status();
/// 
/// // Rollback migrations
/// await manager.rollback(steps: 2);
/// ```
/// 
/// ### Schema Comparison
/// ```dart
/// import 'package:pg_dorm/migrations/migrations.dart';
/// import 'package:pg_dorm/generators/generators.dart';
/// 
/// // Load schemas
/// final oldSchema = await SchemaDefinition.fromFile('old_schema.yaml');
/// final newSchema = await SchemaDefinition.fromFile('new_schema.yaml');
/// 
/// // Compare and generate diff
/// final differ = SchemaDiffer();
/// final diff = differ.compareSchemas(oldSchema, newSchema);
/// 
/// if (diff.hasDestructiveChanges) {
///   print('Warning: Destructive changes detected!');
/// }
/// 
/// // Generate migration file
/// await differ.generateMigrationFile(diff, 'migrations/', 'update_schema');
/// ```
/// 
/// ### CLI Usage
/// ```bash
/// # Initialize migration system
/// dart run bin/migrate.dart init
/// 
/// # Apply all pending migrations
/// dart run bin/migrate.dart migrate --verbose
/// 
/// # Generate migration from schema changes
/// dart run bin/migrate.dart generate -n add_users \
///   --old-schema=old.yaml --new-schema=new.yaml
/// 
/// # Show schema differences
/// dart run bin/migrate.dart diff \
///   --old-schema=old.yaml --new-schema=new.yaml
/// 
/// # Check migration status
/// dart run bin/migrate.dart status
/// 
/// # Rollback last migration
/// dart run bin/migrate.dart rollback
/// ```
/// 
/// ## Migration File Format
/// 
/// Migration files follow a timestamp-based naming convention:
/// - `{timestamp}_{name}.sql` - Up migration
/// - `{timestamp}_{name}.down.sql` - Down migration
/// 
/// ### Example Migration
/// ```sql
/// -- Migration: add_user_table
/// -- Generated on: 2025-01-01T00:00:00.000Z
/// 
/// BEGIN;
/// 
/// CREATE TABLE users (
///   id INTEGER PRIMARY KEY NOT NULL,
///   email VARCHAR(255) NOT NULL UNIQUE,
///   created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
/// );
/// 
/// CREATE INDEX idx_users_email ON users (email);
/// 
/// COMMIT;
/// ```
/// 
/// ## Safety Features
/// 
/// ### Transaction Safety
/// All migrations are executed within database transactions for atomicity.
/// 
/// ### Backup Creation
/// Automatic database backups before applying destructive changes.
/// 
/// ### Dry Run Mode
/// Preview migration effects without making actual changes.
/// 
/// ### Destructive Change Detection
/// Automatic identification of operations that may cause data loss.
/// 
/// ### Rollback Support
/// Every migration includes a corresponding down migration for rollbacks.

library migrations;

export 'migration_manager.dart';
export 'schema_differ.dart'; 