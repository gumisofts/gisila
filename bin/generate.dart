#!/usr/bin/env dart

/// Gisila ORM Code Generator CLI Tool
///
/// Generates Dart model classes and SQL migrations from YAML schema definitions.
///
/// Usage:
///   dart run bin/generate.dart --schema=schema.yaml --output=lib/generated
///   dart run bin/generate.dart --help

import 'dart:io';
import 'package:args/args.dart';
import 'package:gisila/gisila.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'schema',
      abbr: 's',
      help: 'Path to the YAML schema file',
      defaultsTo: 'schema.yaml',
    )
    ..addOption(
      'output',
      abbr: 'o',
      help: 'Output directory for generated files',
      defaultsTo: 'lib/generated',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      help: 'Show this help message',
      negatable: false,
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      help: 'Show verbose output',
      negatable: false,
    )
    ..addFlag(
      'models-only',
      help: 'Generate only model classes',
      negatable: false,
    )
    ..addFlag(
      'migrations-only',
      help: 'Generate only migration files',
      negatable: false,
    );

  try {
    final results = parser.parse(arguments);

    if (results['help'] as bool) {
      _printHelp(parser);
      return;
    }

    final schemaPath = results['schema'] as String;
    final outputPath = results['output'] as String;
    final verbose = results['verbose'] as bool;
    final modelsOnly = results['models-only'] as bool;
    final migrationsOnly = results['migrations-only'] as bool;

    if (verbose) {
      print('🔍 Verbose mode enabled');
    }

    // Validate schema file exists
    final schemaFile = File(schemaPath);
    if (!await schemaFile.exists()) {
      print('❌ Error: Schema file not found: $schemaPath');
      print('');
      print('Make sure the schema file exists and try again.');
      exit(1);
    }

    if (verbose) {
      print('📁 Schema file: $schemaPath');
      print('📁 Output directory: $outputPath');
    }

    try {
      // Create code generator
      final generator = await CodeGenerator.fromSchemaFile(
        schemaPath: schemaPath,
        outputDirectory: outputPath,
      );

      if (verbose) {
        print('');
        print('🏗️  Starting code generation...');
      }

      // Generate everything (we'll implement selective generation later)
      await generator.generateAll();

      print('');
      print('🎉 Code generation completed successfully!');
      print('');
      print('Generated files are available in: $outputPath');

      if (!modelsOnly && !migrationsOnly) {
        print('');
        print('📂 Generated structure:');
        print('   $outputPath/');
        print('   ├── models/');
        print('   │   ├── models.dart (barrel file)');
        print('   │   ├── base_model.dart');
        print('   │   ├── database_context.dart');
        print('   │   └── [model_files].dart');
        print('   ├── migrations/');
        print('   │   ├── [timestamp]_initial_migration.sql');
        print('   │   └── [timestamp]_initial_migration.down.sql');
        print('   ├── setup.sql');
        print('   └── drop.sql');
      }

      print('');
      print('💡 Next steps:');
      if (!migrationsOnly) {
        print(
            '   1. Import generated models: import \'$outputPath/models/models.dart\';');
      }
      if (!modelsOnly) {
        print('   2. Run migrations against your database');
      }
      print(
          '   3. Implement the DatabaseContext methods with your database driver');
    } catch (e, stackTrace) {
      print('❌ Error during code generation: $e');
      if (verbose) {
        print('');
        print('Stack trace:');
        print(stackTrace);
      }
      exit(1);
    }
  } catch (e) {
    print('❌ Error parsing arguments: $e');
    print('');
    _printHelp(parser);
    exit(1);
  }
}

void _printHelp(ArgParser parser) {
  print('Gisila ORM Code Generator');
  print('=========================');
  print('');
  print(
      'Generates Dart model classes and SQL migrations from YAML schema definitions.');
  print('');
  print('Usage:');
  print('  dart run bin/generate.dart [options]');
  print('');
  print('Options:');
  print(parser.usage);
  print('');
  print('Examples:');
  print('  dart run bin/generate.dart');
  print(
      '  dart run bin/generate.dart --schema=my_schema.yaml --output=lib/models');
  print('  dart run bin/generate.dart --models-only --verbose');
  print('  dart run bin/generate.dart --migrations-only');
  print('');
  print('Schema file format:');
  print(
      '  The schema file should be a YAML file defining your database models.');
  print('  See the documentation for the complete schema specification.');
}
