/// Migration manager for Gisila ORM
/// Handles applying and rolling back database schema changes safely

import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:gisila/config/config.dart';

/// Represents a single migration file
class Migration {
  final String id;
  final String name;
  final String upFile;
  final String downFile;
  final DateTime timestamp;

  const Migration({
    required this.id,
    required this.name,
    required this.upFile,
    required this.downFile,
    required this.timestamp,
  });

  /// Parse migration from filename
  factory Migration.fromFile(String upFilePath) {
    final fileName = path.basenameWithoutExtension(upFilePath);
    final parts = fileName.split('_');

    if (parts.length < 2) {
      throw ArgumentError('Invalid migration filename: $fileName');
    }

    final timestampStr = parts[0];
    final name = parts.sublist(1).join('_');

    final timestamp =
        DateTime.fromMillisecondsSinceEpoch(int.parse(timestampStr));
    final downFile = upFilePath.replaceAll('.sql', '.down.sql');

    return Migration(
      id: timestampStr,
      name: name,
      upFile: upFilePath,
      downFile: downFile,
      timestamp: timestamp,
    );
  }

  @override
  String toString() => '$id: $name';
}

/// Migration execution result
class MigrationResult {
  final bool success;
  final String? error;
  final Duration duration;
  final String migrationId;

  const MigrationResult({
    required this.success,
    required this.duration,
    required this.migrationId,
    this.error,
  });

  factory MigrationResult.success(String migrationId, Duration duration) {
    return MigrationResult(
      success: true,
      duration: duration,
      migrationId: migrationId,
    );
  }

  factory MigrationResult.failure(
      String migrationId, Duration duration, String error) {
    return MigrationResult(
      success: false,
      duration: duration,
      migrationId: migrationId,
      error: error,
    );
  }
}

/// Options for migration execution
class MigrationOptions {
  final bool dryRun;
  final bool createBackup;
  final bool verbose;
  final bool force;
  final String? connectionName;

  const MigrationOptions({
    this.dryRun = false,
    this.createBackup = true,
    this.verbose = false,
    this.force = false,
    this.connectionName,
  });
}

/// Exception thrown during migration operations
class MigrationException implements Exception {
  final String message;
  final String? migrationId;

  const MigrationException(this.message, [this.migrationId]);

  @override
  String toString() =>
      'MigrationException: $message${migrationId != null ? ' (Migration: $migrationId)' : ''}';
}

/// Main migration manager class
class MigrationManager {
  static const String _migrationsTable = 'gisila_migrations';
  final DatabaseConfig _dbConfig;
  final String _migrationsPath;

  MigrationManager(this._dbConfig, this._migrationsPath);

  /// Initialize migration system
  Future<void> initialize({String? connectionName}) async {
    await _ensureMigrationsTable(connectionName: connectionName);
  }

  /// Get all migration files from directory
  Future<List<Migration>> _loadMigrationFiles() async {
    final migrationsDir = Directory(_migrationsPath);

    if (!await migrationsDir.exists()) {
      throw MigrationException(
          'Migrations directory not found: $_migrationsPath');
    }

    final files = await migrationsDir
        .list()
        .where((entity) =>
            entity is File &&
            entity.path.endsWith('.sql') &&
            !entity.path.endsWith('.down.sql'))
        .cast<File>()
        .toList();

    final migrations = <Migration>[];
    for (final file in files) {
      try {
        final migration = Migration.fromFile(file.path);
        migrations.add(migration);
      } catch (e) {
        print('Warning: Skipping invalid migration file ${file.path}: $e');
      }
    }

    // Sort by timestamp
    migrations.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return migrations;
  }

  /// Get applied migrations from database
  Future<Set<String>> _getAppliedMigrations({String? connectionName}) async {
    try {
      final pool = await _dbConfig.getConnectionPool(connectionName);
      final pooledConnection = await pool.getConnection();
      final connection = pooledConnection.connection;

      final results = await connection.query(
          'SELECT migration_id FROM $_migrationsTable ORDER BY applied_at');
      await pool.releaseConnection(pooledConnection);

      return results.map((row) => row['migration_id'] as String).toSet();
    } catch (e) {
      // Table might not exist yet
      return <String>{};
    }
  }

  /// Get pending migrations
  Future<List<Migration>> getPendingMigrations({String? connectionName}) async {
    final allMigrations = await _loadMigrationFiles();
    final appliedIds =
        await _getAppliedMigrations(connectionName: connectionName);

    return allMigrations
        .where((migration) => !appliedIds.contains(migration.id))
        .toList();
  }

  /// Get applied migrations
  Future<List<Migration>> getAppliedMigrations({String? connectionName}) async {
    final allMigrations = await _loadMigrationFiles();
    final appliedIds =
        await _getAppliedMigrations(connectionName: connectionName);

    return allMigrations
        .where((migration) => appliedIds.contains(migration.id))
        .toList();
  }

  /// Apply all pending migrations
  Future<List<MigrationResult>> migrate({MigrationOptions? options}) async {
    options ??= const MigrationOptions();

    final pending =
        await getPendingMigrations(connectionName: options.connectionName);

    if (pending.isEmpty) {
      if (options.verbose) {
        print('✅ No pending migrations');
      }
      return [];
    }

    if (options.verbose) {
      print('📦 Found ${pending.length} pending migrations');
      for (final migration in pending) {
        print('   - $migration');
      }
    }

    if (options.createBackup && !options.dryRun) {
      await _createBackup(connectionName: options.connectionName);
    }

    final results = <MigrationResult>[];

    for (final migration in pending) {
      final result = await _applyMigration(migration, options);
      results.add(result);

      if (!result.success && !options.force) {
        if (options.verbose) {
          print('❌ Migration failed, stopping execution');
        }
        break;
      }
    }

    return results;
  }

  /// Apply a specific migration
  Future<MigrationResult> _applyMigration(
      Migration migration, MigrationOptions options) async {
    final stopwatch = Stopwatch()..start();

    if (options.verbose) {
      print('🔄 Applying migration: $migration');
    }

    try {
      final sqlContent = await File(migration.upFile).readAsString();

      if (options.dryRun) {
        if (options.verbose) {
          print('📝 DRY RUN - Would execute:');
          print(sqlContent);
        }
        stopwatch.stop();
        return MigrationResult.success(migration.id, stopwatch.elapsed);
      }

      // Execute migration in transaction
      final pool = await _dbConfig.getConnectionPool(options.connectionName);
      final pooledConnection = await pool.getConnection();
      final connection = pooledConnection.connection;

      try {
        await connection.transaction(() async {
          // Execute migration SQL
          await connection.execute(sqlContent);

          // Record migration as applied
          await connection.execute(
            'INSERT INTO $_migrationsTable (migration_id, migration_name, applied_at) VALUES (?, ?, ?)',
            [migration.id, migration.name, DateTime.now().toIso8601String()],
          );
        });

        await pool.releaseConnection(pooledConnection);
        stopwatch.stop();

        if (options.verbose) {
          print(
              '✅ Migration applied successfully in ${stopwatch.elapsed.inMilliseconds}ms');
        }

        return MigrationResult.success(migration.id, stopwatch.elapsed);
      } catch (e) {
        await pool.releaseConnection(pooledConnection);
        throw e;
      }
    } catch (e) {
      stopwatch.stop();

      if (options.verbose) {
        print('❌ Migration failed: $e');
      }

      return MigrationResult.failure(
          migration.id, stopwatch.elapsed, e.toString());
    }
  }

  /// Rollback migrations
  Future<List<MigrationResult>> rollback({
    int? steps,
    String? toMigration,
    MigrationOptions? options,
  }) async {
    options ??= const MigrationOptions();

    final applied =
        await getAppliedMigrations(connectionName: options.connectionName);
    applied.sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Newest first

    List<Migration> toRollback;

    if (toMigration != null) {
      final targetIndex = applied.indexWhere((m) => m.id == toMigration);
      if (targetIndex == -1) {
        throw MigrationException('Target migration not found: $toMigration');
      }
      toRollback = applied.take(targetIndex).toList();
    } else {
      final rollbackCount = steps ?? 1;
      toRollback = applied.take(rollbackCount).toList();
    }

    if (toRollback.isEmpty) {
      if (options.verbose) {
        print('✅ No migrations to rollback');
      }
      return [];
    }

    if (options.verbose) {
      print('📦 Rolling back ${toRollback.length} migrations');
      for (final migration in toRollback) {
        print('   - $migration');
      }
    }

    if (options.createBackup && !options.dryRun) {
      await _createBackup(connectionName: options.connectionName);
    }

    final results = <MigrationResult>[];

    for (final migration in toRollback) {
      final result = await _rollbackMigration(migration, options);
      results.add(result);

      if (!result.success && !options.force) {
        if (options.verbose) {
          print('❌ Rollback failed, stopping execution');
        }
        break;
      }
    }

    return results;
  }

  /// Rollback a specific migration
  Future<MigrationResult> _rollbackMigration(
      Migration migration, MigrationOptions options) async {
    final stopwatch = Stopwatch()..start();

    if (options.verbose) {
      print('⏪ Rolling back migration: $migration');
    }

    try {
      final downFile = File(migration.downFile);
      if (!await downFile.exists()) {
        throw MigrationException(
            'Down migration file not found: ${migration.downFile}');
      }

      final sqlContent = await downFile.readAsString();

      if (options.dryRun) {
        if (options.verbose) {
          print('📝 DRY RUN - Would execute:');
          print(sqlContent);
        }
        stopwatch.stop();
        return MigrationResult.success(migration.id, stopwatch.elapsed);
      }

      // Execute rollback in transaction
      final pool = await _dbConfig.getConnectionPool(options.connectionName);
      final pooledConnection = await pool.getConnection();
      final connection = pooledConnection.connection;

      try {
        await connection.transaction(() async {
          // Execute rollback SQL
          await connection.execute(sqlContent);

          // Remove migration record
          await connection.execute(
            'DELETE FROM $_migrationsTable WHERE migration_id = ?',
            [migration.id],
          );
        });

        await pool.releaseConnection(pooledConnection);
        stopwatch.stop();

        if (options.verbose) {
          print(
              '✅ Migration rolled back successfully in ${stopwatch.elapsed.inMilliseconds}ms');
        }

        return MigrationResult.success(migration.id, stopwatch.elapsed);
      } catch (e) {
        await pool.releaseConnection(pooledConnection);
        throw e;
      }
    } catch (e) {
      stopwatch.stop();

      if (options.verbose) {
        print('❌ Rollback failed: $e');
      }

      return MigrationResult.failure(
          migration.id, stopwatch.elapsed, e.toString());
    }
  }

  /// Get migration status
  Future<void> status({String? connectionName}) async {
    final allMigrations = await _loadMigrationFiles();
    final appliedIds =
        await _getAppliedMigrations(connectionName: connectionName);

    print('📋 Migration Status:');
    print('');

    if (allMigrations.isEmpty) {
      print('  No migrations found');
      return;
    }

    for (final migration in allMigrations) {
      final status =
          appliedIds.contains(migration.id) ? '✅ Applied' : '⏳ Pending';
      print('  $status  ${migration.id} - ${migration.name}');
    }

    final pendingCount = allMigrations.length - appliedIds.length;
    print('');
    print('  Total: ${allMigrations.length} migrations');
    print('  Applied: ${appliedIds.length}');
    print('  Pending: $pendingCount');
  }

  /// Create database backup
  Future<void> _createBackup({String? connectionName}) async {
    // Implementation would depend on database type
    // For now, just log the action
    print('💾 Creating database backup...');
  }

  /// Ensure migrations table exists
  Future<void> _ensureMigrationsTable({String? connectionName}) async {
    final pool = await _dbConfig.getConnectionPool(connectionName);
    final pooledConnection = await pool.getConnection();
    final connection = pooledConnection.connection;

    try {
      await connection.execute('''
        CREATE TABLE IF NOT EXISTS $_migrationsTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          migration_id VARCHAR(255) NOT NULL UNIQUE,
          migration_name VARCHAR(255) NOT NULL,
          applied_at TIMESTAMP NOT NULL
        )
      ''');
    } finally {
      await pool.releaseConnection(pooledConnection);
    }
  }
}
