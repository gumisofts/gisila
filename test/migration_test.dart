/// Test for the migration system functionality
library;

import 'dart:io';
import 'package:pg_dorm/migrations/migrations.dart';
import 'package:pg_dorm/generators/generators.dart';

void main() async {
  print('🧪 Testing Migration System');
  print('');

  await testSchemaDiffer();
}

Future<void> testSchemaDiffer() async {
  print('📖 Testing Schema Differ');
  
  try {
    // Create old schema
    final oldSchemaYaml = '''
User:
  columns:
    name:
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

    print('🔍 Parsing schemas...');
    final oldSchema = SchemaDefinition.fromYaml(oldSchemaYaml);
    final newSchema = SchemaDefinition.fromYaml(newSchemaYaml);
    
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
    
    print('');
    print('🔧 SQL Operations:');
    for (final operation in diff.operations) {
      print('-- ${operation.change}');
      print(operation.upSql);
      print('');
    }
    
    // Generate migration files
    print('📝 Generating migration files...');
    await Directory('test/generated_migrations').create(recursive: true);
    await differ.generateMigrationFile(
      diff, 
      'test/generated_migrations', 
      'test_schema_changes'
    );

    print('✅ Schema differ test completed successfully!');

  } catch (e) {
    print('❌ Schema differ test failed: $e');
    print('Stack trace:');
    print(e);
  }
} 