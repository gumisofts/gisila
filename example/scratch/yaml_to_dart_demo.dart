import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as p;

/// A utility class to convert YAML database schema definitions into Dart object models.
/// It generates Dart classes with appropriate types, nullability, and also creates
/// Table and Column constants for use with a SQL query builder.
class YamlSchemaToDartGenerator {
  final String yamlContent;
  final String outputDirectory;
  final String outputFileName; // New: Name of the single output file

  /// Creates a [YamlSchemaToDartGenerator] instance.
  /// [yamlContent] The raw YAML string defining the database schema.
  /// [outputDirectory] The directory where the generated Dart file will be saved.
  /// [outputFileName] The name of the single Dart file to generate (e.g., 'models.dart').
  YamlSchemaToDartGenerator(this.yamlContent,
      {this.outputDirectory = 'lib/models',
      this.outputFileName = 'models.dart'});

  /// Maps YAML data types to their corresponding Dart types.
  String _mapYamlTypeToDartType(String yamlType, bool isNullable) {
    String dartType;
    switch (yamlType.toLowerCase()) {
      case 'varchar':
      case 'char':
      case 'text':
      case 'uuid': // Assuming UUIDs are handled as strings in Dart
        dartType = 'String';
        break;
      case 'integer':
      case 'smallint':
      case 'bigint':
        dartType = 'int';
        break;
      case 'float':
      case 'double':
      case 'numeric':
        dartType = 'double';
        break;
      case 'boolean':
        dartType = 'bool';
        break;
      case 'timestamp':
      case 'date':
        dartType = 'DateTime';
        break;
      default:
        // Assume it's a reference to another generated class
        dartType = yamlType;
        break;
    }
    return isNullable ? '$dartType?' : dartType;
  }

  /// Generates the Dart class content for a given entity.
  /// [entityName] The name of the entity (e.g., 'User', 'Book').
  /// [entityData] The parsed YAML data for the entity.
  /// [allEntities] A map of all entity names to their parsed data, used for resolving references.
  String _generateDartClass(
      String entityName, YamlMap entityData, Map<String, YamlMap> allEntities) {
    final StringBuffer buffer = StringBuffer();
    final String className = _capitalize(entityName);
    final String tableName = entityData['db_table'] ?? entityName.toLowerCase();

    // Class definition
    buffer.writeln('class $className {');

    // Fields
    final YamlMap columns = entityData['columns'] as YamlMap;
    final List<String> constructorParams = [];

    columns.forEach((columnName, columnDefinition) {
      final String fieldName = _snakeCaseToCamelCase(columnName.toString());
      final YamlMap colDef = columnDefinition as YamlMap;

      final bool isNullable = colDef['is_null'] ?? false;
      final String yamlType = colDef['type'].toString();
      final bool isRequired = !(colDef['is_null'] ??
          false); // Field is required if not explicitly nullable

      String dartType;
      String paramPrefix = isRequired ? 'required this.' : 'this.';

      if (colDef.containsKey('many_to_many') &&
          colDef['many_to_many'] == true) {
        // Many-to-many relationship
        final String referencedEntity = colDef['references'].toString();
        dartType = 'List<${_capitalize(referencedEntity)}>';
        buffer.writeln(
            '  final $dartType? $fieldName;'); // Many-to-many lists are always nullable
        constructorParams.add('this.$fieldName');
      } else if (colDef.containsKey('references')) {
        // One-to-many / Many-to-one relationship (foreign key and object reference)
        final String referencedEntity = colDef['references'].toString();
        final String referencedClassName = _capitalize(referencedEntity);
        final YamlMap referencedEntityData = allEntities[referencedEntity]!;
        final YamlMap referencedColumns =
            referencedEntityData['columns'] as YamlMap;

        // Find primary key of referenced entity to determine FK type
        String fkType = 'int'; // Default to int for FK
        referencedColumns.forEach((refColName, refColDef) {
          if ((refColDef as YamlMap)['is_primary'] == true) {
            fkType =
                _mapYamlTypeToDartType(refColDef['type'].toString(), false);
          }
        });

        // Add foreign key field
        buffer.writeln(
            '  final ${isRequired ? fkType : '$fkType?'} ${fieldName}Id;');
        constructorParams
            .add('${isRequired ? 'required ' : ''}this.${fieldName}Id');

        // Add reference object field (always nullable, as it might not be loaded)
        dartType = _mapYamlTypeToDartType(
            yamlType, true); // Object reference is always nullable
        buffer.writeln('  final $dartType $fieldName;');
        constructorParams.add('this.$fieldName');
      } else {
        // Regular column
        dartType = _mapYamlTypeToDartType(yamlType, isNullable);
        buffer.writeln('  final $dartType $fieldName;');
        constructorParams.add('$paramPrefix$fieldName');
      }
    });

    // Add reverse relationships (if any)
    allEntities.forEach((otherEntityName, otherEntityData) {
      final YamlMap otherColumns = otherEntityData['columns'] as YamlMap;
      otherColumns.forEach((otherColumnName, otherColumnDefinition) {
        final YamlMap otherColDef = otherColumnDefinition as YamlMap;
        if (otherColDef.containsKey('references') &&
            otherColDef['references'] == entityName) {
          if (otherColDef.containsKey('reverse_name')) {
            final String reverseName =
                _snakeCaseToCamelCase(otherColDef['reverse_name'].toString());
            final String otherClassName = _capitalize(otherEntityName);
            buffer.writeln(
                '  final List<$otherClassName>? $reverseName;'); // Reverse relationships are lists, always nullable
            constructorParams.add('this.$reverseName');
          }
        } else if (otherColDef.containsKey('many_to_many') &&
            otherColDef['many_to_many'] == true &&
            otherColDef['references'] == entityName) {
          if (otherColDef.containsKey('reverse_name')) {
            final String reverseName =
                _snakeCaseToCamelCase(otherColDef['reverse_name'].toString());
            final String otherClassName = _capitalize(otherEntityName);
            buffer.writeln(
                '  final List<$otherClassName>? $reverseName;'); // Reverse relationships are lists, always nullable
            constructorParams.add('this.$reverseName');
          }
        }
      });
    });

    // Constructor
    buffer.writeln('');
    buffer.writeln('  const $className({');
    buffer.writeln('    ${constructorParams.join(',\n    ')},');
    buffer.writeln('  });');

    // fromMap factory constructor
    buffer.writeln('');
    buffer.writeln('  factory $className.fromMap(Map<String, dynamic> map) {');
    buffer.writeln('    return $className(');
    columns.forEach((columnName, columnDefinition) {
      final String fieldName = _snakeCaseToCamelCase(columnName.toString());
      final YamlMap colDef = columnDefinition as YamlMap;
      final String yamlType = colDef['type'].toString();
      final bool isNullable = colDef['is_null'] ?? false;

      if (colDef.containsKey('many_to_many') &&
          colDef['many_to_many'] == true) {
        final String referencedEntity = colDef['references'].toString();
        final String referencedClassName = _capitalize(referencedEntity);
        buffer.writeln(
            '      $fieldName: (map[\'$columnName\'] as List<dynamic>?)?.map((e) => $referencedClassName.fromMap(e as Map<String, dynamic>)).toList(),');
      } else if (colDef.containsKey('references')) {
        final String referencedEntity = colDef['references'].toString();
        final String referencedClassName = _capitalize(referencedEntity);
        final YamlMap referencedEntityData = allEntities[referencedEntity]!;
        final YamlMap referencedColumns =
            referencedEntityData['columns'] as YamlMap;
        String fkType = 'int'; // Default to int for FK
        referencedColumns.forEach((refColName, refColDef) {
          if ((refColDef as YamlMap)['is_primary'] == true) {
            fkType =
                _mapYamlTypeToDartType(refColDef['type'].toString(), false);
          }
        });

        // Assuming foreign key is named like 'column_name_id' in the map
        buffer.writeln(
            '      ${fieldName}Id: map[\'${columnName}_id\'] as $fkType${isNullable ? '?' : ''},');
        buffer.writeln(
            '      $fieldName: map[\'$columnName\'] != null ? $referencedClassName.fromMap(map[\'$columnName\'] as Map<String, dynamic>) : null,');
      } else {
        String castType = _mapYamlTypeToDartType(
            yamlType, false); // Cast to non-nullable type first
        if (yamlType.toLowerCase() == 'timestamp' ||
            yamlType.toLowerCase() == 'date') {
          buffer.writeln(
              '      $fieldName: ${isNullable ? 'map[\'$columnName\'] != null ? ' : ''}DateTime.parse(map[\'$columnName\'].toString())${isNullable ? ' : null' : ''},');
        } else {
          buffer.writeln(
              '      $fieldName: map[\'$columnName\'] as $castType${isNullable ? '?' : ''},');
        }
      }
    });

    // Handle reverse relationships in fromMap (assuming they are loaded as lists of maps)
    allEntities.forEach((otherEntityName, otherEntityData) {
      final YamlMap otherColumns = otherEntityData['columns'] as YamlMap;
      otherColumns.forEach((otherColumnName, otherColumnDefinition) {
        final YamlMap otherColDef = otherColumnDefinition as YamlMap;
        if (otherColDef.containsKey('references') &&
            otherColDef['references'] == entityName) {
          if (otherColDef.containsKey('reverse_name')) {
            final String reverseName =
                _snakeCaseToCamelCase(otherColDef['reverse_name'].toString());
            final String otherClassName = _capitalize(otherEntityName);
            buffer.writeln(
                '      $reverseName: (map[\'${otherColDef['reverse_name']}\'] as List<dynamic>?)?.map((e) => $otherClassName.fromMap(e as Map<String, dynamic>)).toList(),');
          }
        } else if (otherColDef.containsKey('many_to_many') &&
            otherColDef['many_to_many'] == true &&
            otherColDef['references'] == entityName) {
          if (otherColDef.containsKey('reverse_name')) {
            final String reverseName =
                _snakeCaseToCamelCase(otherColDef['reverse_name'].toString());
            final String otherClassName = _capitalize(otherEntityName);
            buffer.writeln(
                '      $reverseName: (map[\'${otherColDef['reverse_name']}\'] as List<dynamic>?)?.map((e) => $otherClassName.fromMap(e as Map<String, dynamic>)).toList(),');
          }
        }
      });
    });

    buffer.writeln('    );');
    buffer.writeln('  }');

    // toMap method
    buffer.writeln('');
    buffer.writeln('  Map<String, dynamic> toMap() {');
    buffer.writeln('    return {');
    columns.forEach((columnName, columnDefinition) {
      final String fieldName = _snakeCaseToCamelCase(columnName.toString());
      final YamlMap colDef = columnDefinition as YamlMap;
      final bool isNullable = colDef['is_null'] ?? false;

      if (colDef.containsKey('many_to_many') &&
          colDef['many_to_many'] == true) {
        buffer.writeln(
            '      \'$columnName\': $fieldName?.map((e) => e.toMap()).toList(),');
      } else if (colDef.containsKey('references')) {
        buffer.writeln('      \'${columnName}_id\': ${fieldName}Id,');
        buffer.writeln('      \'$columnName\': $fieldName?.toMap(),');
      } else if (colDef['type'].toString().toLowerCase() == 'timestamp' ||
          colDef['type'].toString().toLowerCase() == 'date') {
        buffer.writeln(
            '      \'$columnName\': $fieldName${isNullable ? '?' : ''}.toIso8601String(),');
      } else {
        buffer.writeln('      \'$columnName\': $fieldName,');
      }
    });

    // Handle reverse relationships in toMap
    allEntities.forEach((otherEntityName, otherEntityData) {
      final YamlMap otherColumns = otherEntityData['columns'] as YamlMap;
      otherColumns.forEach((otherColumnName, otherColumnDefinition) {
        final YamlMap otherColDef = otherColumnDefinition as YamlMap;
        if (otherColDef.containsKey('references') &&
            otherColDef['references'] == entityName) {
          if (otherColDef.containsKey('reverse_name')) {
            final String reverseName =
                _snakeCaseToCamelCase(otherColDef['reverse_name'].toString());
            buffer.writeln(
                '      \'${otherColDef['reverse_name']}\': $reverseName?.map((e) => e.toMap()).toList(),');
          }
        } else if (otherColDef.containsKey('many_to_many') &&
            otherColDef['many_to_many'] == true &&
            otherColDef['references'] == entityName) {
          if (otherColDef.containsKey('reverse_name')) {
            final String reverseName =
                _snakeCaseToCamelCase(otherColDef['reverse_name'].toString());
            buffer.writeln(
                '      \'${otherColDef['reverse_name']}\': $reverseName?.map((e) => e.toMap()).toList(),');
          }
        }
      });
    });

    buffer.writeln('    };');
    buffer.writeln('  }');

    // equals and hashCode for comparison
    buffer.writeln('');
    buffer.writeln('  @override');
    buffer.writeln('  bool operator ==(Object other) {');
    buffer.writeln('    if (identical(this, other)) return true;');
    buffer.writeln('    return other is $className &&');
    final List<String> equalityChecks = [];
    columns.forEach((columnName, columnDefinition) {
      final String fieldName = _snakeCaseToCamelCase(columnName.toString());
      final YamlMap colDef = columnDefinition as YamlMap;
      if (colDef.containsKey('many_to_many') &&
          colDef['many_to_many'] == true) {
        equalityChecks.add(
            'const DeepCollectionEquality().equals($fieldName, other.$fieldName)');
      } else if (colDef.containsKey('references')) {
        equalityChecks.add('${fieldName}Id == other.${fieldName}Id');
        equalityChecks.add('$fieldName == other.$fieldName');
      } else {
        equalityChecks.add('$fieldName == other.$fieldName');
      }
    });
    // Handle reverse relationships in equals
    allEntities.forEach((otherEntityName, otherEntityData) {
      final YamlMap otherColumns = otherEntityData['columns'] as YamlMap;
      otherColumns.forEach((otherColumnName, otherColumnDefinition) {
        final YamlMap otherColDef = otherColumnDefinition as YamlMap;
        if (otherColDef.containsKey('references') &&
            otherColDef['references'] == entityName) {
          if (otherColDef.containsKey('reverse_name')) {
            final String reverseName =
                _snakeCaseToCamelCase(otherColDef['reverse_name'].toString());
            equalityChecks.add(
                'const DeepCollectionEquality().equals($reverseName, other.$reverseName)');
          }
        } else if (otherColDef.containsKey('many_to_many') &&
            otherColDef['many_to_many'] == true &&
            otherColDef['references'] == entityName) {
          if (otherColDef.containsKey('reverse_name')) {
            final String reverseName =
                _snakeCaseToCamelCase(otherColDef['reverse_name'].toString());
            equalityChecks.add(
                'const DeepCollectionEquality().equals($reverseName, other.$reverseName)');
          }
        }
      });
    });
    buffer.writeln('           ${equalityChecks.join(' &&\n           ')} &&');
    buffer.writeln('           true;'); // Final true to end the chain
    buffer.writeln('  }');

    buffer.writeln('');
    buffer.writeln('  @override');
    buffer.writeln('  int get hashCode => Object.hashAll([ ');
    final List<String> hashCodeFields = [];
    columns.forEach((columnName, columnDefinition) {
      final String fieldName = _snakeCaseToCamelCase(columnName.toString());
      final YamlMap colDef = columnDefinition as YamlMap;
      if (colDef.containsKey('many_to_many') &&
          colDef['many_to_many'] == true) {
        hashCodeFields.add('...($fieldName ?? [])');
      } else if (colDef.containsKey('references')) {
        hashCodeFields.add('${fieldName}Id');
        hashCodeFields.add(fieldName);
      } else {
        hashCodeFields.add(fieldName);
      }
    });
    // Handle reverse relationships in hashCode
    allEntities.forEach((otherEntityName, otherEntityData) {
      final YamlMap otherColumns = otherEntityData['columns'] as YamlMap;
      otherColumns.forEach((otherColumnName, otherColumnDefinition) {
        final YamlMap otherColDef = otherColumnDefinition as YamlMap;
        if (otherColDef.containsKey('references') &&
            otherColDef['references'] == entityName) {
          if (otherColDef.containsKey('reverse_name')) {
            final String reverseName =
                _snakeCaseToCamelCase(otherColDef['reverse_name'].toString());
            hashCodeFields.add('...($reverseName ?? [])');
          }
        } else if (otherColDef.containsKey('many_to_many') &&
            otherColDef['many_to_many'] == true &&
            otherColDef['references'] == entityName) {
          if (otherColDef.containsKey('reverse_name')) {
            final String reverseName =
                _snakeCaseToCamelCase(otherColDef['reverse_name'].toString());
            hashCodeFields.add('...($reverseName ?? [])');
          }
        }
      });
    });
    buffer.writeln('    ${hashCodeFields.join(',\n    ')},');
    buffer.writeln('  ]);');
    buffer.writeln('');

    buffer.writeln('  @override');
    buffer.writeln('  String toString() {');
    buffer.writeln('    return \'$className({\'');
    final List<String> toStringFields = [];
    columns.forEach((columnName, columnDefinition) {
      final String fieldName = _snakeCaseToCamelCase(columnName.toString());
      final YamlMap colDef = columnDefinition as YamlMap;
      if (colDef.containsKey('references')) {
        toStringFields.add('\'${fieldName}Id\': ${fieldName}Id');
        toStringFields.add('\'$fieldName\': $fieldName');
      } else {
        toStringFields.add('\'$fieldName\': $fieldName');
      }
    });
    // Handle reverse relationships in toString
    allEntities.forEach((otherEntityName, otherEntityData) {
      final YamlMap otherColumns = otherEntityData['columns'] as YamlMap;
      otherColumns.forEach((otherColumnName, otherColumnDefinition) {
        final YamlMap otherColDef = otherColumnDefinition as YamlMap;
        if (otherColDef.containsKey('references') &&
            otherColDef['references'] == entityName) {
          if (otherColDef.containsKey('reverse_name')) {
            final String reverseName =
                _snakeCaseToCamelCase(otherColDef['reverse_name'].toString());
            toStringFields.add('\'$reverseName\': $reverseName');
          }
        } else if (otherColDef.containsKey('many_to_many') &&
            otherColDef['many_to_many'] == true &&
            otherColDef['references'] == entityName) {
          if (otherColDef.containsKey('reverse_name')) {
            final String reverseName =
                _snakeCaseToCamelCase(otherColDef['reverse_name'].toString());
            toStringFields.add('\'$reverseName\': $reverseName');
          }
        }
      });
    });
    buffer.writeln('    \'${toStringFields.join(', ')}\'');
    buffer.writeln('    \'})\';');
    buffer.writeln('  }');

    buffer.writeln('}'); // End of class

    // Generate Table and Column constants for QueryBuilder
    buffer.writeln('');
    buffer.writeln('// --- QueryBuilder Constants for $className ---');
    buffer.writeln(
        'const Table ${entityName.toLowerCase()}Table = Table(\'$tableName\', alias: \'${entityName.toLowerCase().substring(0, 1)}\');');

    columns.forEach((columnName, columnDefinition) {
      final String fieldName = _snakeCaseToCamelCase(columnName.toString());
      final YamlMap colDef = columnDefinition as YamlMap;
      final String yamlType = colDef['type'].toString();

      if (colDef.containsKey('references')) {
        // For foreign key, generate column for the ID
        final String referencedEntity = colDef['references'].toString();
        final YamlMap referencedEntityData = allEntities[referencedEntity]!;
        final YamlMap referencedColumns =
            referencedEntityData['columns'] as YamlMap;
        String fkType = 'int'; // Default to int for FK
        referencedColumns.forEach((refColName, refColDef) {
          if ((refColDef as YamlMap)['is_primary'] == true) {
            fkType =
                _mapYamlTypeToDartType(refColDef['type'].toString(), false);
          }
        });
        buffer.writeln(
            'const Column<$fkType> ${entityName.toLowerCase()}${_capitalize(fieldName)}IdCol = Column<$fkType>(${entityName.toLowerCase()}Table, \'${columnName}_id\');');
      } else if (!(colDef.containsKey('many_to_many') &&
          colDef['many_to_many'] == true)) {
        // Do not generate Column for many-to-many relationships (they are not direct DB columns)
        final String dartType = _mapYamlTypeToDartType(
            yamlType, false); // Use non-nullable for Column type
        buffer.writeln(
            'const Column<$dartType> ${entityName.toLowerCase()}${_capitalize(fieldName)}Col = Column<$dartType>(${entityName.toLowerCase()}Table, \'$columnName\');');
      }
    });
    buffer.writeln('\n'); // Add a newline between classes for readability

    return buffer.toString();
  }

  /// Converts snake_case to camelCase.
  String _snakeCaseToCamelCase(String text) {
    List<String> parts = text.split('_');
    if (parts.isEmpty) {
      return '';
    }
    // The first part remains lowercase
    String camelCase = parts[0];
    // Subsequent parts are capitalized
    for (int i = 1; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        camelCase += parts[i][0].toUpperCase() + parts[i].substring(1);
      }
    }
    return camelCase;
  }

  /// Capitalizes the first letter of a string.
  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  /// Generates Dart object models from the YAML schema.
  Future<void> generate() async {
    final YamlMap doc = loadYaml(yamlContent) as YamlMap;

    // First pass to collect all entity names and their data
    final Map<String, YamlMap> allEntities = {};
    doc.forEach((key, value) {
      if (value is YamlMap && value.containsKey('columns')) {
        allEntities[key.toString()] = value;
      }
    });

    // Create output directory if it doesn't exist
    final Directory outputDir = Directory(outputDirectory);
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    final StringBuffer combinedContent = StringBuffer();
    combinedContent.writeln('// Generated by YamlSchemaToDartGenerator');
    combinedContent.writeln('// DO NOT EDIT MANUALLY');
    combinedContent.writeln('');
    combinedContent.writeln(
        "import 'package:collection/collection.dart'; // For DeepCollectionEquality");
    combinedContent.writeln(
        "import '../query_builder.dart'; // Assuming query_builder.dart is in the parent directory");
    combinedContent.writeln('');

    // Second pass to generate Dart classes, now with knowledge of all entities
    for (var entry in allEntities.entries) {
      final String entityName = entry.key;
      final YamlMap entityData = entry.value;
      combinedContent
          .write(_generateDartClass(entityName, entityData, allEntities));
    }

    final File outputFile = File(p.join(outputDirectory, outputFileName));
    await outputFile.writeAsString(combinedContent.toString());
    print('Generated ${outputFile.path}');

    print('\nDart object models generated successfully in "$outputDirectory"!');
  }
}

// --- Main function to run the generator ---
void main() async {
  final String yamlSchema = '''
User:
  columns:
    first_name:
      type: varchar
      is_null: false
    last_name:
      type: varchar
      is_null: true
      allow_blank: true
    email:
      type: varchar
      is_null: false
      is_unique: true
      is_index: true
      allow_blank: false
    password:
      type: varchar
      is_null: false
      is_unique: false
      is_index: false
      allow_blank: false
    date_joined:
      type: timestamp
      is_null: false
      is_unique: false
      is_index: false
      allow_blank: false
  db_table: users # Optional: specify custom table name
  indexes:
    idx_user_email:
      columns:
        - email

Author:
  columns:
    first_name:
      type: varchar
      is_null: false
    last_name:
      type: varchar
      is_null: true
      allow_blank: true
    email:
      type: varchar
      is_null: false
      is_unique: true
      is_index: true
      allow_blank: false
  db_table: authors

Book:
  columns:
    title:
      type: varchar
      is_null: false
      is_unique: true
      is_index: true
      is_primary: true # This is a primary key
      allow_blank: false
    subtitle:
      type: varchar
      is_null: true
    description:
      type: text
      is_null: true
    published_date:
      type: date
      is_null: true
    isbn:
      type: varchar
      is_null: true
      is_unique: true
      is_index: true
    page_count:
      type: integer
      is_null: true
    author:
      type: Author # This is a reference to the Author class
      references: Author
      is_index: true
      reverse_name: written_books # The field name in Author for books by this author
    reviewers:
      type: User
      many_to_many: true # This is a many-to-many relationship
      references: User
      is_null: true
      is_unique: false
      is_index: true
      reverse_name: reviewed_books # The field name in User for books reviewed by this user
  db_table: books

Review:
  columns:
    book:
      type: Book
      references: Book
      is_index: true
      reverse_name: reviews
    reviewer:
      type: User
      references: User
      reverse_name: reviews
    rating:
      type: integer
    review_text:
      type: text
      is_null: true
    review_date:
      type: timestamp
      is_null: false
      is_unique: false
      is_index: false
      allow_blank: false
    is_approved:
      type: boolean
      is_null: false
      is_unique: false
      is_index: false
      allow_blank: false
    is_flagged:
      type: boolean
      is_null: false
      is_unique: false
      is_index: false
      allow_blank: false
    is_deleted:
      type: boolean
      is_null: false
      is_unique: false
      is_index: false
      allow_blank: false
    is_spam:
      type: boolean
      is_null: false
      is_unique: false
      is_index: false
      allow_blank: false
    is_inappropriate:
      type: boolean
      is_null: false
      is_unique: false
      is_index: false
      allow_blank: false
    is_harmful:
      type: boolean
      is_null: false
      is_unique: false
      is_index: false
      allow_blank: false
  db_table: reviews
  indexes:
    idx_review_book:
      columns:
        - book
    idx_review_reviewer:
      columns:
        - reviewer
''';

  // To run this code, you'll need to add the 'yaml' and 'path' packages to your pubspec.yaml:
  // dependencies:
  //   yaml: ^3.1.0
  //   path: ^1.8.0
  //   collection: ^1.18.0 # For DeepCollectionEquality in generated equals/hashCode

  final generator = YamlSchemaToDartGenerator(yamlSchema,
      outputDirectory: 'generated_models', outputFileName: 'models.dart');
  await generator.generate();

  print('\nExample of how to use the generated classes:');
  print('// After running this generator, you will have a single file:');
  print('// generated_models/models.dart');
  print('');
  print('// You would then import it in your application:');
  print(
      '// import \'package:your_project_name/generated_models/models.dart\';');
  print(
      '// import \'package:your_project_name/query_builder.dart\'; // Assuming query_builder.dart is in a sibling directory to generated_models');
  print('');
  print('// Example usage with generated constants and QueryBuilder:');
  print('/*');
  print('import \'package:your_project_name/generated_models/models.dart\';');
  print('import \'package:your_project_name/query_builder.dart\';');
  print('');
  print('void main() {');
  print('  // Using generated Table and Column constants');
  print('  var userQuery = QueryBuilder()');
  print('      .from(userTable)');
  print('      .select([userEmailCol, userFirstNameCol])');
  print('      .where(userAgeCol, SqlOperator.greaterThan, 25)');
  print('      .build();');
  print('  print(userQuery[\'sql\']);');
  print('  print(userQuery[\'parameters\']);');
  print('');
  print('  // Example of creating a generated object');
  print('  final newUser = User(');
  print('    firstName: \'Jane\',');
  print('    lastName: \'Doe\',');
  print('    email: \'jane.doe@example.com\',');
  print('    password: \'securepassword\',');
  print('    dateJoined: DateTime.now(),');
  print('  );');
  print('  print(newUser.toMap());');
  print('');
  print('  // Example with relationships (assuming data is loaded and mapped)');
  print(
      '  final newAuthor = Author(firstName: \'Test\', lastName: \'Author\', email: \'test@example.com\');');
  print('  final newBook = Book(');
  print('    title: \'The Dart Guide\',');
  print('    authorId: 1, // Assuming the author ID');
  print('    author: newAuthor,');
  print('    publishedDate: DateTime(2023, 10, 26),');
  print('    reviewers: [newUser], // Many-to-many relationship');
  print('  );');
  print('  print(newBook.toMap());');
  print('}');
  print('*/');
}
