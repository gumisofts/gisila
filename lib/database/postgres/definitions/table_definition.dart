import 'package:pg_dorm/database/postgres/definitions/column_definitions.dart';

class IndexDefinition {
  String name;
  List<String> columns;
  bool isUnique;

  IndexDefinition({
    required this.name,
    required this.columns,
    this.isUnique = false,
  });

  factory IndexDefinition.fromYamlMap(MapEntry<String, dynamic> entry) {
    return IndexDefinition(
      name: entry.key,
      columns: (entry.value['columns'] as List).cast<String>(),
      isUnique: entry.value['isUnique'] as bool? ?? false,
    );
  }
}

class TableDefinition {
  String name;
  List<BaseColumnDefinition> columns;
  List<IndexDefinition> indexes;

  TableDefinition(
      {required this.name, this.columns = const [], this.indexes = const []});

  factory TableDefinition.fromYamlMap(MapEntry<String, dynamic> entry) {
    return TableDefinition(
      name: entry.key,
      columns: (entry.value['columns'] as Map<String, dynamic>)
          .entries
          .map((columnEntry) => BaseColumnDefinition.fromJson(columnEntry))
          .toList(),
      indexes:
          (((entry.value['indexes'] as Map<String, dynamic>?) ?? {}).entries)
              .map((e) => IndexDefinition.fromYamlMap(e))
              .toList(),
    );
  }
}
