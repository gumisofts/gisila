#!/usr/bin/env dart

/// Migration CLI tool for Gisila ORM
/// Manages database schema changes and migrations
library;

import 'dart:io';
import 'dart:async';
import 'package:args/args.dart';
import 'package:gisila/gisila.dart';

void main(List<String> arguments) async {
  final parser = ArgParser();

  // Global options
  parser.addOption('config',
      abbr: 'c',
      help: 'Database configuration file',
      defaultsTo: 'database.yaml');
  parser.addOption('migrations-path',
      abbr: 'm',
      help: 'Path to migrations directory',
      defaultsTo: 'migrations');
  parser.addOption('connection', help: 'Database connection name');
  parser.addFlag('verbose',
      abbr: 'v', help: 'Enable verbose output', negatable: false);
  parser.addFlag('help',
      abbr: 'h', help: 'Show this help message', negatable: false);

  // Commands
  parser.addCommand('migrate', createMigrateCommand());
  parser.addCommand('rollback', createRollbackCommand());
  parser.addCommand('status', createStatusCommand());
  parser.addCommand('generate', createGenerateCommand());
  parser.addCommand('diff', createDiffCommand());
  parser.addCommand('init', createInitCommand());

  try {
    final results = parser.parse(arguments);

    if (results['help'] as bool || results.command == null) {
      showHelp(parser);
      return;
    }

    await runCommand(results);
  } catch (e) {
    print('❌ Error: $e');
    print('');
    showHelp(parser);
    exit(1);
  }
}

ArgParser createMigrateCommand() {
  final parser = ArgParser();
  parser.addFlag('dry-run',
      help: 'Show what would be executed without making changes',
      negatable: false);
  parser.addFlag('force',
      help: 'Continue applying migrations even if one fails', negatable: false);
  parser.addFlag('no-backup',
      help: 'Skip creating database backup', negatable: false);
  return parser;
}

ArgParser createRollbackCommand() {
  final parser = ArgParser();
  parser.addOption('steps',
      abbr: 's', help: 'Number of migrations to rollback', defaultsTo: '1');
  parser.addOption('to', abbr: 't', help: 'Rollback to specific migration ID');
  parser.addFlag('dry-run',
      help: 'Show what would be executed without making changes',
      negatable: false);
  parser.addFlag('force',
      help: 'Continue rolling back even if one fails', negatable: false);
  parser.addFlag('no-backup',
      help: 'Skip creating database backup', negatable: false);
  return parser;
}

ArgParser createStatusCommand() {
  final parser = ArgParser();
  return parser;
}

ArgParser createGenerateCommand() {
  final parser = ArgParser();
  parser.addOption('name', abbr: 'n', help: 'Migration name', mandatory: true);
  parser.addOption('old-schema',
      help: 'Path to old schema file for comparison');
  parser.addOption('new-schema',
      help: 'Path to new schema file for comparison');
  return parser;
}

ArgParser createDiffCommand() {
  final parser = ArgParser();
  parser.addOption('old-schema',
      help: 'Path to old schema file', mandatory: true);
  parser.addOption('new-schema',
      help: 'Path to new schema file', mandatory: true);
  parser.addFlag('generate-migration',
      help: 'Generate migration files from diff', negatable: false);
  parser.addOption('migration-name',
      help: 'Name for generated migration', defaultsTo: 'schema_changes');
  return parser;
}

ArgParser createInitCommand() {
  final parser = ArgParser();
  return parser;
}

Future<void> runCommand(ArgResults results) async {
  final configPath = results['config'] as String;
  final migrationsPath = results['migrations-path'] as String;
  final connectionName = results['connection'] as String?;
  final verbose = results['verbose'] as bool;

  // Load database configuration
  late DatabaseConfig dbConfig;
  try {
    dbConfig = await DatabaseConfig.fromFile(configPath);
  } catch (e) {
    throw Exception(
        'Failed to load database configuration from $configPath: $e');
  }

  final manager = MigrationManager(dbConfig, migrationsPath);

  switch (results.command?.name) {
    case 'migrate':
      await runMigrate(manager, results.command!, connectionName, verbose);
      break;
    case 'rollback':
      await runRollback(manager, results.command!, connectionName, verbose);
      break;
    case 'status':
      await runStatus(manager, connectionName);
      break;
    case 'generate':
      await runGenerate(results.command!, migrationsPath);
      break;
    case 'diff':
      await runDiff(results.command!, migrationsPath);
      break;
    case 'init':
      await runInit(manager, connectionName, verbose);
      break;
    default:
      throw Exception('Unknown command: ${results.command?.name}');
  }
}

Future<void> runMigrate(
  MigrationManager manager,
  ArgResults command,
  String? connectionName,
  bool verbose,
) async {
  print('🚀 Starting database migration...');
  print('');

  final options = MigrationOptions(
    dryRun: command['dry-run'] as bool,
    force: command['force'] as bool,
    createBackup: !(command['no-backup'] as bool),
    verbose: verbose,
    connectionName: connectionName,
  );

  await manager.initialize(connectionName: connectionName);
  final results = await manager.migrate(options: options);

  if (results.isEmpty) {
    print('✅ Database is up to date!');
    return;
  }

  print('');
  print('📊 Migration Results:');
  var successCount = 0;
  var failureCount = 0;
  var totalTime = Duration.zero;

  for (final result in results) {
    totalTime += result.duration;
    if (result.success) {
      successCount++;
      print('  ✅ ${result.migrationId} (${result.duration.inMilliseconds}ms)');
    } else {
      failureCount++;
      print('  ❌ ${result.migrationId} (${result.duration.inMilliseconds}ms)');
      print('     Error: ${result.error}');
    }
  }

  print('');
  print('📈 Summary:');
  print('  Applied: $successCount migrations');
  if (failureCount > 0) {
    print('  Failed: $failureCount migrations');
  }
  print('  Total time: ${totalTime.inMilliseconds}ms');

  if (failureCount > 0) {
    exit(1);
  }
}

Future<void> runRollback(
  MigrationManager manager,
  ArgResults command,
  String? connectionName,
  bool verbose,
) async {
  print('⏪ Starting migration rollback...');
  print('');

  final stepsStr = command['steps'] as String;
  final toMigration = command['to'] as String?;

  int? steps;
  if (toMigration == null) {
    steps = int.tryParse(stepsStr);
    if (steps == null) {
      throw Exception('Invalid steps value: $stepsStr');
    }
  }

  final options = MigrationOptions(
    dryRun: command['dry-run'] as bool,
    force: command['force'] as bool,
    createBackup: !(command['no-backup'] as bool),
    verbose: verbose,
    connectionName: connectionName,
  );

  await manager.initialize(connectionName: connectionName);
  final results = await manager.rollback(
    steps: steps,
    toMigration: toMigration,
    options: options,
  );

  if (results.isEmpty) {
    print('✅ No migrations to rollback!');
    return;
  }

  print('');
  print('📊 Rollback Results:');
  var successCount = 0;
  var failureCount = 0;
  var totalTime = Duration.zero;

  for (final result in results) {
    totalTime += result.duration;
    if (result.success) {
      successCount++;
      print('  ✅ ${result.migrationId} (${result.duration.inMilliseconds}ms)');
    } else {
      failureCount++;
      print('  ❌ ${result.migrationId} (${result.duration.inMilliseconds}ms)');
      print('     Error: ${result.error}');
    }
  }

  print('');
  print('📈 Summary:');
  print('  Rolled back: $successCount migrations');
  if (failureCount > 0) {
    print('  Failed: $failureCount migrations');
  }
  print('  Total time: ${totalTime.inMilliseconds}ms');

  if (failureCount > 0) {
    exit(1);
  }
}

Future<void> runStatus(
  MigrationManager manager,
  String? connectionName,
) async {
  await manager.initialize(connectionName: connectionName);
  await manager.status(connectionName: connectionName);
}

Future<void> runGenerate(ArgResults command, String migrationsPath) async {
  final name = command['name'] as String;
  final oldSchemaPath = command['old-schema'] as String?;
  final newSchemaPath = command['new-schema'] as String?;

  if (oldSchemaPath != null && newSchemaPath != null) {
    // Generate migration from schema diff
    print('🔍 Comparing schemas...');

    final oldSchema = await SchemaDefinition.fromFile(oldSchemaPath);
    final newSchema = await SchemaDefinition.fromFile(newSchemaPath);

    final differ = SchemaDiffer();
    final diff = differ.compareSchemas(oldSchema, newSchema);

    if (diff.isEmpty) {
      print('✅ No schema changes detected');
      return;
    }

    print('📦 Found ${diff.changes.length} changes:');
    for (final change in diff.changes) {
      final indicator = diff.hasDestructiveChanges ? '⚠️ ' : '✅ ';
      print('  $indicator$change');
    }

    if (diff.hasDestructiveChanges) {
      print('');
      print(
          '⚠️  WARNING: This migration contains destructive changes that may result in data loss!');
    }

    await differ.generateMigrationFile(diff, migrationsPath, name);
  } else {
    // Generate empty migration
    print('📝 Generating empty migration: $name');

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final upFile = File('$migrationsPath/${timestamp}_$name.sql');
    final downFile = File('$migrationsPath/${timestamp}_$name.down.sql');

    await Directory(migrationsPath).create(recursive: true);

    final upContent = '''-- Migration: $name
-- Generated on: ${DateTime.now().toIso8601String()}

BEGIN;

-- Add your migration SQL here

COMMIT;
''';

    final downContent = '''-- Down migration: $name
-- Generated on: ${DateTime.now().toIso8601String()}

BEGIN;

-- Add your rollback SQL here

COMMIT;
''';

    await upFile.writeAsString(upContent);
    await downFile.writeAsString(downContent);

    print('✅ Generated migration files:');
    print('   Up:   ${upFile.path}');
    print('   Down: ${downFile.path}');
  }
}

Future<void> runDiff(ArgResults command, String migrationsPath) async {
  final oldSchemaPath = command['old-schema'] as String;
  final newSchemaPath = command['new-schema'] as String;
  final generateMigration = command['generate-migration'] as bool;
  final migrationName = command['migration-name'] as String;

  print('🔍 Comparing schemas...');
  print('  Old: $oldSchemaPath');
  print('  New: $newSchemaPath');
  print('');

  final oldSchema = await SchemaDefinition.fromFile(oldSchemaPath);
  final newSchema = await SchemaDefinition.fromFile(newSchemaPath);

  final differ = SchemaDiffer();
  final diff = differ.compareSchemas(oldSchema, newSchema);

  if (diff.isEmpty) {
    print('✅ No differences found between schemas');
    return;
  }

  print('📦 Found ${diff.changes.length} differences:');
  print('');

  for (final change in diff.changes) {
    final indicator = _getChangeIndicator(change.type);
    print('  $indicator $change');
  }

  if (diff.hasDestructiveChanges) {
    print('');
    print(
        '⚠️  WARNING: Schema contains destructive changes that may result in data loss!');
  }

  print('');
  print('🔧 SQL Operations:');
  print('');

  for (final operation in diff.operations) {
    print('-- ${operation.change}');
    print(operation.upSql);
    print('');
  }

  if (generateMigration) {
    print('');
    await differ.generateMigrationFile(diff, migrationsPath, migrationName);
  }
}

Future<void> runInit(
  MigrationManager manager,
  String? connectionName,
  bool verbose,
) async {
  print('🏗️  Initializing migration system...');

  try {
    await manager.initialize(connectionName: connectionName);
    print('✅ Migration system initialized successfully!');

    if (verbose) {
      print('');
      print('💡 Next steps:');
      print(
          '   1. Generate your first migration: dart run bin/migrate.dart generate -n initial_schema');
      print('   2. Apply migrations: dart run bin/migrate.dart migrate');
      print('   3. Check status: dart run bin/migrate.dart status');
    }
  } catch (e) {
    print('❌ Failed to initialize migration system: $e');
    exit(1);
  }
}

String _getChangeIndicator(ChangeType type) {
  switch (type) {
    case ChangeType.createTable:
    case ChangeType.addColumn:
    case ChangeType.addIndex:
    case ChangeType.addForeignKey:
      return '➕';
    case ChangeType.dropTable:
    case ChangeType.dropColumn:
    case ChangeType.dropIndex:
    case ChangeType.dropForeignKey:
      return '➖';
    case ChangeType.renameTable:
    case ChangeType.renameColumn:
    case ChangeType.modifyColumn:
      return '🔄';
  }
}

void showHelp(ArgParser parser) {
  print('Gisila Migration Manager');
  print('');
  print('Manages database schema changes and migrations for Gisila ORM');
  print('');
  print('USAGE:');
  print('  dart run bin/migrate.dart <command> [options]');
  print('');
  print('COMMANDS:');
  print('  migrate    Apply pending migrations to the database');
  print('  rollback   Rollback applied migrations');
  print('  status     Show migration status');
  print('  generate   Generate new migration file');
  print('  diff       Compare two schema files and show differences');
  print('  init       Initialize migration system');
  print('');
  print('GLOBAL OPTIONS:');
  print(parser.usage);
  print('');
  print('EXAMPLES:');
  print('  # Initialize migration system');
  print('  dart run bin/migrate.dart init');
  print('');
  print('  # Apply all pending migrations');
  print('  dart run bin/migrate.dart migrate -v');
  print('');
  print('  # Rollback last 2 migrations');
  print('  dart run bin/migrate.dart rollback -s 2');
  print('');
  print('  # Generate migration from schema changes');
  print(
      '  dart run bin/migrate.dart generate -n add_user_table --old-schema=old.yaml --new-schema=new.yaml');
  print('');
  print('  # Show differences between schemas');
  print(
      '  dart run bin/migrate.dart diff --old-schema=old.yaml --new-schema=new.yaml');
  print('');
  print('  # Check migration status');
  print('  dart run bin/migrate.dart status');
}
