import 'package:pg_dorm/database/postgres/data_types/mappings.dart';

class BaseColumnDefinition<T> {
  late String name;
  bool isNull;
  bool isUnique;
  bool isIndex;
  bool isPrimaryKey;
  T? defaultValue;
  ColumnsDataType dbType;
  String? references;
  bool isManyToManyReferences;
  BaseColumnDefinition(
      {required String name,
      required this.dbType,
      this.isNull = false,
      this.isUnique = false,
      this.isIndex = false,
      this.isPrimaryKey = false,
      this.isManyToManyReferences = false,
      this.defaultValue,
      this.references}) {
    this.name = properColumnName(name);
  }

  String properColumnName(String name) {
    final n = name
        .split('_')
        .map((el) => "${el[0].toUpperCase()}${el.substring(1)}")
        .join();

    return "${n[0].toLowerCase()}${n.substring(1)}";
  }

  factory BaseColumnDefinition.fromJson(MapEntry<String, dynamic> entry) {
    return BaseColumnDefinition(
      name: entry.key,
      dbType: ColumnsDataType.values
              .map((value) => value.name)
              .toList()
              .contains(entry.value['type'])
          ? ColumnsDataType.values.byName(entry.value['type'] as String)
          : ColumnsDataType.foreignKey,
      isNull: entry.value['is_null'] as bool? ?? false,
      references: ColumnsDataType.values
              .map((value) => value.name)
              .toList()
              .contains(entry.value['type'])
          ? null
          : entry.value['type'],
      isUnique: entry.value['is_unique'] as bool? ?? false,
      isIndex: entry.value['is_index'] as bool? ?? false,
      isManyToManyReferences: entry.value['many_to_many'] as bool? ?? false,
      isPrimaryKey: entry.value['is_primary'] as bool? ?? false,
      defaultValue: entry.value['default_value'],
    );
  }
}
