/// Example of using the Gisila code generator programmatically
///
/// This example demonstrates how to generate model classes and
/// migration files from a schema definition.

import 'dart:io';
import '../lib/generators/code_generator.dart';
import '../lib/generators/schema_parser.dart';

Future<void> main() async {
  print('Gisila Code Generator Example');
  print('=============================');
  print('');

  // Example 1: Generate from existing schema file
  await generateFromSchemaFile();

  print('');

  // Example 2: Generate from programmatically created schema
  await generateFromProgrammaticSchema();

  print('');
  print('✅ All examples completed successfully!');
}

/// Example 1: Generate code from an existing schema file
Future<void> generateFromSchemaFile() async {
  print('📖 Example 1: Generating from schema file');

  const schemaPath = 'test/models/schema.yaml';
  const outputPath = 'example/generated_from_file';

  try {
    // Create generator from schema file
    final generator = await CodeGenerator.fromSchemaFile(
      schemaPath: schemaPath,
      outputDirectory: outputPath,
    );

    // Generate all artifacts
    await generator.generateAll();

    print('📁 Generated files in: $outputPath');

    // List generated files
    await _listGeneratedFiles(outputPath);
  } catch (e) {
    print('❌ Error: $e');
  }
}

/// Example 2: Generate code from programmatically created schema
Future<void> generateFromProgrammaticSchema() async {
  print('🔧 Example 2: Generating from programmatic schema');

  const outputPath = 'example/generated_programmatic';

  try {
    // Create schema programmatically
    final schema = _createExampleSchema();

    // Create generator
    final generator = CodeGenerator(
      schema: schema,
      outputDirectory: outputPath,
    );

    // Generate all artifacts
    await generator.generateAll();

    print('📁 Generated files in: $outputPath');

    // List generated files
    await _listGeneratedFiles(outputPath);
  } catch (e) {
    print('❌ Error: $e');
  }
}

/// Create an example schema programmatically
SchemaDefinition _createExampleSchema() {
  // Create User model
  final userModel = ModelDefinition(
    name: 'User',
    tableName: 'users',
    columns: [
      ColumnDefinition(
        name: 'id',
        type: ColumnType.integer,
        constraints: const ColumnConstraints(
          isPrimary: true,
          isNull: false,
          isUnique: true,
          isIndex: true,
        ),
      ),
      ColumnDefinition(
        name: 'email',
        type: ColumnType.varchar,
        constraints: const ColumnConstraints(
          isNull: false,
          isUnique: true,
          isIndex: true,
          allowBlank: false,
        ),
      ),
      ColumnDefinition(
        name: 'first_name',
        type: ColumnType.varchar,
        constraints: const ColumnConstraints(
          isNull: false,
          allowBlank: false,
        ),
      ),
      ColumnDefinition(
        name: 'last_name',
        type: ColumnType.varchar,
        constraints: const ColumnConstraints(
          isNull: true,
          allowBlank: true,
        ),
      ),
      ColumnDefinition(
        name: 'created_at',
        type: ColumnType.timestamp,
        constraints: const ColumnConstraints(
          isNull: false,
          defaultValue: 'NOW()',
        ),
      ),
      ColumnDefinition(
        name: 'is_active',
        type: ColumnType.boolean,
        constraints: const ColumnConstraints(
          isNull: false,
          defaultValue: true,
        ),
      ),
    ],
  );

  // Create Post model with foreign key to User
  final postModel = ModelDefinition(
    name: 'Post',
    tableName: 'posts',
    columns: [
      ColumnDefinition(
        name: 'id',
        type: ColumnType.integer,
        constraints: const ColumnConstraints(
          isPrimary: true,
          isNull: false,
          isUnique: true,
          isIndex: true,
        ),
      ),
      ColumnDefinition(
        name: 'title',
        type: ColumnType.varchar,
        constraints: const ColumnConstraints(
          isNull: false,
          allowBlank: false,
        ),
      ),
      ColumnDefinition(
        name: 'content',
        type: ColumnType.text,
        constraints: const ColumnConstraints(
          isNull: true,
        ),
      ),
      ColumnDefinition(
        name: 'author',
        type: ColumnType.foreignKey,
        constraints: const ColumnConstraints(
          isNull: false,
          isIndex: true,
        ),
        relationship: const RelationshipConfig(
          references: 'User',
          reverseName: 'posts',
          onDelete: 'CASCADE',
          onUpdate: 'CASCADE',
        ),
      ),
      ColumnDefinition(
        name: 'published_at',
        type: ColumnType.timestamp,
        constraints: const ColumnConstraints(
          isNull: true,
        ),
      ),
      ColumnDefinition(
        name: 'is_published',
        type: ColumnType.boolean,
        constraints: const ColumnConstraints(
          isNull: false,
          defaultValue: false,
        ),
      ),
    ],
    indexes: [
      const IndexDefinition(
        name: 'idx_posts_title',
        columns: ['title'],
      ),
      const IndexDefinition(
        name: 'idx_posts_published',
        columns: ['is_published', 'published_at'],
      ),
    ],
  );

  // Create Tag model
  final tagModel = ModelDefinition(
    name: 'Tag',
    tableName: 'tags',
    columns: [
      ColumnDefinition(
        name: 'id',
        type: ColumnType.integer,
        constraints: const ColumnConstraints(
          isPrimary: true,
          isNull: false,
          isUnique: true,
          isIndex: true,
        ),
      ),
      ColumnDefinition(
        name: 'name',
        type: ColumnType.varchar,
        constraints: const ColumnConstraints(
          isNull: false,
          isUnique: true,
          allowBlank: false,
        ),
      ),
      ColumnDefinition(
        name: 'description',
        type: ColumnType.text,
        constraints: const ColumnConstraints(
          isNull: true,
        ),
      ),
      ColumnDefinition(
        name: 'posts',
        type: ColumnType.manyToMany,
        constraints: const ColumnConstraints(
          isNull: true,
        ),
        relationship: const RelationshipConfig(
          references: 'Post',
          reverseName: 'tags',
          isManyToMany: true,
        ),
      ),
    ],
  );

  return SchemaDefinition(models: [userModel, postModel, tagModel]);
}

/// List all generated files in a directory
Future<void> _listGeneratedFiles(String path) async {
  final dir = Directory(path);
  if (!await dir.exists()) {
    print('   Directory does not exist: $path');
    return;
  }

  print('   Generated files:');

  await for (final entity in dir.list(recursive: true)) {
    if (entity is File) {
      final relativePath = entity.path.replaceFirst('$path/', '');
      final fileSize = await entity.length();
      print('     📄 $relativePath (${_formatBytes(fileSize)})');
    }
  }
}

/// Format bytes in human readable format
String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
