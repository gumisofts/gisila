/// Gisila ORM Code Generation Module
/// 
/// This module provides comprehensive code generation capabilities
/// for creating Dart model classes, SQL migrations, and database
/// setup files from YAML schema definitions.
/// 
/// ## Features:
/// 
/// - **Schema Parsing**: Parse YAML schema definitions with validation
/// - **Model Generation**: Generate Dart classes with CRUD operations
/// - **Migration Generation**: Create SQL migration files
/// - **Relationship Handling**: Support for foreign keys and many-to-many
/// - **Validation**: Built-in model validation
/// - **CLI Tool**: Command-line interface for code generation
/// 
/// ## Basic Usage:
/// 
/// ```dart
/// import 'package:gisila/generators/generators.dart';
/// 
/// // Generate from schema file
/// final generator = await CodeGenerator.fromSchemaFile(
///   schemaPath: 'schema.yaml',
///   outputDirectory: 'lib/generated',
/// );
/// 
/// await generator.generateAll();
/// ```
/// 
/// ## CLI Usage:
/// 
/// ```bash
/// dart run bin/generate.dart --schema=schema.yaml --output=lib/generated
/// ```
/// 
/// ## Schema Format:
/// 
/// ```yaml
/// User:
///   columns:
///     first_name:
///       type: varchar
///       is_null: false
///     email:
///       type: varchar
///       is_null: false
///       is_unique: true
///       is_index: true
/// 
/// Book:
///   columns:
///     title:
///       type: varchar
///       is_null: false
///     author:
///       type: Author
///       references: Author
///       reverse_name: books
/// ```
library gisila.generators;

export 'schema_parser.dart';
export 'model_generator.dart';
export 'code_generator.dart';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:source_gen/source_gen.dart';

class ModelFromJsonAnnotation extends GeneratorForAnnotation<JsonSerializable> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    final buffer = StringBuffer();

    return buffer.toString();
  }
}
