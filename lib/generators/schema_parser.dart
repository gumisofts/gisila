/// Schema parser for Gisila ORM
/// 
/// Parses YAML schema definitions and converts them into structured
/// model representations for code generation.
library gisila.generators.schema_parser;

import 'dart:io';
import 'package:yaml/yaml.dart';

/// Supported column data types
enum ColumnType {
  varchar,
  text,
  integer,
  bigint,
  boolean,
  date,
  timestamp,
  decimal,
  json,
  uuid,
  // Reference types
  foreignKey,
  manyToMany,
}

/// Column constraint configuration
class ColumnConstraints {
  final bool isNull;
  final bool isUnique;
  final bool isIndex;
  final bool isPrimary;
  final bool allowBlank;
  final dynamic defaultValue;

  const ColumnConstraints({
    this.isNull = true,
    this.isUnique = false,
    this.isIndex = false,
    this.isPrimary = false,
    this.allowBlank = true,
    this.defaultValue,
  });

  factory ColumnConstraints.fromMap(Map<String, dynamic> map) {
    return ColumnConstraints(
      isNull: map['is_null'] as bool? ?? true,
      isUnique: map['is_unique'] as bool? ?? false,
      isIndex: map['is_index'] as bool? ?? false,
      isPrimary: map['is_primary'] as bool? ?? false,
      allowBlank: map['allow_blank'] as bool? ?? true,
      defaultValue: map['default'],
    );
  }
}

/// Relationship configuration
class RelationshipConfig {
  final String? references;
  final String? reverseName;
  final bool isManyToMany;
  final String? onDelete;
  final String? onUpdate;

  const RelationshipConfig({
    this.references,
    this.reverseName,
    this.isManyToMany = false,
    this.onDelete,
    this.onUpdate,
  });

  factory RelationshipConfig.fromMap(Map<String, dynamic> map) {
    // If references is not set but type is a model name, use type as references
    String? references = map['references'] as String?;
    if (references == null) {
      final typeStr = map['type'] as String?;
      if (typeStr != null && ColumnDefinition._isModelType(typeStr)) {
        references = typeStr;
      }
    }
    
    return RelationshipConfig(
      references: references,
      reverseName: map['reverse_name'] as String?,
      isManyToMany: map['many_to_many'] as bool? ?? false,
      onDelete: map['on_delete'] as String?,
      onUpdate: map['on_update'] as String?,
    );
  }
}

/// Column definition
class ColumnDefinition {
  final String name;
  final ColumnType type;
  final ColumnConstraints constraints;
  final RelationshipConfig? relationship;

  const ColumnDefinition({
    required this.name,
    required this.type,
    required this.constraints,
    this.relationship,
  });

  /// Get Dart type representation
  String get dartType {
    final baseType = _getDartBaseType();
    final nullable = constraints.isNull && !constraints.isPrimary ? '?' : '';
    return '$baseType$nullable';
  }

  String _getDartBaseType() {
    switch (type) {
      case ColumnType.varchar:
      case ColumnType.text:
      case ColumnType.uuid:
        return 'String';
      case ColumnType.integer:
      case ColumnType.bigint:
        return 'int';
      case ColumnType.boolean:
        return 'bool';
      case ColumnType.date:
      case ColumnType.timestamp:
        return 'DateTime';
      case ColumnType.decimal:
        return 'double';
      case ColumnType.json:
        return 'Map<String, dynamic>';
      case ColumnType.foreignKey:
        return relationship?.references ?? 'Object';
      case ColumnType.manyToMany:
        return 'List<${relationship?.references ?? 'Object'}>';
    }
  }

  /// Get PostgreSQL type representation
  String get postgresType {
    switch (type) {
      case ColumnType.varchar:
        return 'VARCHAR(255)';
      case ColumnType.text:
        return 'TEXT';
      case ColumnType.integer:
        return 'INTEGER';
      case ColumnType.bigint:
        return 'BIGINT';
      case ColumnType.boolean:
        return 'BOOLEAN';
      case ColumnType.date:
        return 'DATE';
      case ColumnType.timestamp:
        return 'TIMESTAMP WITH TIME ZONE';
      case ColumnType.decimal:
        return 'DECIMAL';
      case ColumnType.json:
        return 'JSONB';
      case ColumnType.uuid:
        return 'UUID';
      case ColumnType.foreignKey:
        return 'INTEGER';
      case ColumnType.manyToMany:
        return ''; // Handled by junction table
    }
  }

  bool get isRelationship => type == ColumnType.foreignKey || type == ColumnType.manyToMany;

  factory ColumnDefinition.fromMap(String name, Map<String, dynamic> map) {
    final typeStr = map['type'] as String;
    ColumnType type;
    RelationshipConfig? relationship;

    // Check if it's a relationship (either has 'references' or type is capitalized model name)
    if (map.containsKey('references') || _isModelType(typeStr)) {
      if (map['many_to_many'] == true) {
        type = ColumnType.manyToMany;
      } else {
        type = ColumnType.foreignKey;
      }
      relationship = RelationshipConfig.fromMap(map);
    } else {
      // Parse regular column type
      type = _parseColumnType(typeStr);
    }

    final constraints = ColumnConstraints.fromMap(map);

    return ColumnDefinition(
      name: name,
      type: type,
      constraints: constraints,
      relationship: relationship,
    );
  }

  /// Check if type string represents a model (starts with uppercase)
  static bool _isModelType(String typeStr) {
    return typeStr.isNotEmpty && typeStr[0] == typeStr[0].toUpperCase() && 
           !_isBuiltinType(typeStr);
  }

  /// Check if type string is a builtin type
  static bool _isBuiltinType(String typeStr) {
    const builtinTypes = {
      'varchar', 'text', 'integer', 'bigint', 'boolean', 
      'date', 'timestamp', 'decimal', 'json', 'uuid'
    };
    return builtinTypes.contains(typeStr.toLowerCase());
  }

  static ColumnType _parseColumnType(String typeStr) {
    switch (typeStr.toLowerCase()) {
      case 'varchar':
        return ColumnType.varchar;
      case 'text':
        return ColumnType.text;
      case 'integer':
        return ColumnType.integer;
      case 'bigint':
        return ColumnType.bigint;
      case 'boolean':
        return ColumnType.boolean;
      case 'date':
        return ColumnType.date;
      case 'timestamp':
        return ColumnType.timestamp;
      case 'decimal':
        return ColumnType.decimal;
      case 'json':
        return ColumnType.json;
      case 'uuid':
        return ColumnType.uuid;
      default:
        throw ArgumentError('Unknown column type: $typeStr');
    }
  }
}

/// Index definition
class IndexDefinition {
  final String name;
  final List<String> columns;
  final bool isUnique;

  const IndexDefinition({
    required this.name,
    required this.columns,
    this.isUnique = false,
  });

  factory IndexDefinition.fromMap(String name, Map<String, dynamic> map) {
    final columns = (map['columns'] as List?)?.cast<String>() ?? [];
    final isUnique = map['unique'] as bool? ?? false;

    return IndexDefinition(
      name: name,
      columns: columns,
      isUnique: isUnique,
    );
  }
}

/// Model definition
class ModelDefinition {
  final String name;
  final String tableName;
  final List<ColumnDefinition> columns;
  final List<IndexDefinition> indexes;

  const ModelDefinition({
    required this.name,
    required this.tableName,
    required this.columns,
    this.indexes = const [],
  });

  /// Get all regular columns (non-relationship)
  List<ColumnDefinition> get regularColumns => 
      columns.where((col) => !col.isRelationship).toList();

  /// Get all foreign key columns
  List<ColumnDefinition> get foreignKeyColumns => 
      columns.where((col) => col.type == ColumnType.foreignKey).toList();

  /// Get all many-to-many relationships
  List<ColumnDefinition> get manyToManyColumns => 
      columns.where((col) => col.type == ColumnType.manyToMany).toList();

  /// Get primary key column
  ColumnDefinition? get primaryKey => 
      columns.where((col) => col.constraints.isPrimary).firstOrNull;

  /// Get unique columns
  List<ColumnDefinition> get uniqueColumns => 
      columns.where((col) => col.constraints.isUnique).toList();

  /// Get indexed columns
  List<ColumnDefinition> get indexedColumns => 
      columns.where((col) => col.constraints.isIndex).toList();

  factory ModelDefinition.fromMap(String name, Map<String, dynamic> map) {
    final tableName = map['db_table'] as String? ?? _toSnakeCase(name);
    final columnsMap = map['columns'] as Map<String, dynamic>? ?? {};
    final indexesMap = map['indexes'] as Map<String, dynamic>? ?? {};

    // Parse columns
    final columns = <ColumnDefinition>[];
    
    // Add implicit primary key if not defined
    bool hasPrimaryKey = false;
    for (final entry in columnsMap.entries) {
      final columnData = entry.value is Map<String, dynamic> 
          ? entry.value as Map<String, dynamic>
          : SchemaDefinition._convertYamlToMap(entry.value);
      final column = ColumnDefinition.fromMap(entry.key, columnData);
      columns.add(column);
      if (column.constraints.isPrimary) {
        hasPrimaryKey = true;
      }
    }

    // Add implicit id column if no primary key is defined
    if (!hasPrimaryKey) {
      columns.insert(0, ColumnDefinition(
        name: 'id',
        type: ColumnType.integer,
        constraints: const ColumnConstraints(
          isPrimary: true,
          isNull: false,
          isUnique: true,
          isIndex: true,
        ),
      ));
    }

    // Parse indexes
    final indexes = <IndexDefinition>[];
    for (final entry in indexesMap.entries) {
      final indexData = entry.value is Map<String, dynamic> 
          ? entry.value as Map<String, dynamic>
          : SchemaDefinition._convertYamlToMap(entry.value);
      final index = IndexDefinition.fromMap(entry.key, indexData);
      indexes.add(index);
    }

    return ModelDefinition(
      name: name,
      tableName: tableName,
      columns: columns,
      indexes: indexes,
    );
  }

  static String _toSnakeCase(String input) {
    return input
        .replaceAllMapped(RegExp(r'[A-Z]'), (match) => '_${match.group(0)?.toLowerCase()}')
        .replaceFirst(RegExp(r'^_'), '');
  }
}

/// Complete schema definition
class SchemaDefinition {
  final List<ModelDefinition> models;
  final Map<String, ModelDefinition> _modelMap = {};

  SchemaDefinition({required this.models}) {
    for (final model in models) {
      _modelMap[model.name] = model;
    }
  }

  /// Get model by name
  ModelDefinition? getModel(String name) => _modelMap[name];

  /// Get all model names
  List<String> get modelNames => models.map((m) => m.name).toList();

  /// Get relationships between models
  List<RelationshipInfo> get relationships {
    final relationships = <RelationshipInfo>[];
    
    for (final model in models) {
      for (final column in model.columns) {
        if (column.isRelationship && column.relationship != null) {
          relationships.add(RelationshipInfo(
            fromModel: model.name,
            toModel: column.relationship!.references!,
            fromColumn: column.name,
            reverseName: column.relationship!.reverseName,
            isManyToMany: column.relationship!.isManyToMany,
          ));
        }
      }
    }
    
    return relationships;
  }

  factory SchemaDefinition.fromYaml(String yamlContent) {
    final yaml = loadYaml(yamlContent);
    final models = <ModelDefinition>[];

    if (yaml is! Map) {
      throw ArgumentError('Schema must be a YAML map/object');
    }

    for (final entry in yaml.entries) {
      final modelName = entry.key as String;
      final modelData = _convertYamlToMap(entry.value);
      
      final model = ModelDefinition.fromMap(modelName, modelData);
      models.add(model);
    }

    return SchemaDefinition(models: models);
  }

  /// Convert YamlMap/YamlList to regular Dart Map/List
  static Map<String, dynamic> _convertYamlToMap(dynamic yaml) {
    if (yaml is YamlMap) {
      final map = <String, dynamic>{};
      for (final entry in yaml.entries) {
        map[entry.key as String] = _convertYamlValue(entry.value);
      }
      return map;
    } else if (yaml is Map) {
      final map = <String, dynamic>{};
      for (final entry in yaml.entries) {
        map[entry.key as String] = _convertYamlValue(entry.value);
      }
      return map;
    } else {
      throw ArgumentError('Expected YAML map, got ${yaml.runtimeType}');
    }
  }

  /// Convert any YAML value to regular Dart value
  static dynamic _convertYamlValue(dynamic value) {
    if (value is YamlMap) {
      return _convertYamlToMap(value);
    } else if (value is YamlList) {
      return value.map(_convertYamlValue).toList();
    } else if (value is List) {
      return value.map(_convertYamlValue).toList();
    } else {
      return value;
    }
  }

  static Future<SchemaDefinition> fromFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('Schema file not found: $filePath');
    }

    final content = await file.readAsString();
    return SchemaDefinition.fromYaml(content);
  }
}

/// Relationship information between models
class RelationshipInfo {
  final String fromModel;
  final String toModel;
  final String fromColumn;
  final String? reverseName;
  final bool isManyToMany;

  const RelationshipInfo({
    required this.fromModel,
    required this.toModel,
    required this.fromColumn,
    this.reverseName,
    this.isManyToMany = false,
  });

  String get junctionTableName => isManyToMany 
      ? '${_toSnakeCase(fromModel)}_${_toSnakeCase(toModel)}'
      : '';

  static String _toSnakeCase(String input) {
    return input
        .replaceAllMapped(RegExp(r'[A-Z]'), (match) => '_${match.group(0)?.toLowerCase()}')
        .replaceFirst(RegExp(r'^_'), '');
  }
}

/// Extension to provide firstOrNull functionality
extension IterableExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
} 