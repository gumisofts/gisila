import 'package:pg_dorm/database/postgres/data_types/mappings.dart';
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
  String? tableName;
  List<BaseColumnDefinition> columns;
  List<IndexDefinition> indexes;
  late BaseColumnDefinition primaryColumnDefinition;
  String properTableName(String name) {
    final n = name
        .split('_')
        .map((el) => "${el[0].toUpperCase()}${el.substring(1)}")
        .join();

    return n;
  }

  TableDefinition(
      {required this.name,
      this.columns = const [],
      this.indexes = const [],
      this.tableName}) {
    name = properTableName(name);
    tableName ??= name.toLowerCase();

    primaryColumnDefinition = columns.firstWhere((col) => col.isPrimaryKey,
        orElse: () => BaseColumnDefinition(
              name: 'id',
              dbType: ColumnsDataType.uuid,
              isIndex: true,
              isPrimaryKey: true,
              isUnique: true,
            ));
  }

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
