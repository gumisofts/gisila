import 'package:build/build.dart';
import 'package:gisila/database/postgres/data_types/mappings.dart';
import 'package:gisila/database/postgres/definitions/table_definition.dart';

Future<void> queryGenerator(
  List<TableDefinition> definitions,
  BuildStep buildStep,
) async {
  final buffer = StringBuffer();
  final queryId = buildStep.inputId.changeExtension('.query.g.dart');
  // final partOf = buildStep.inputId.changeExtension('.g.dart');
  final partId = buildStep.inputId.changeExtension('.dart');

  buffer.writeln("part of '${partId.pathSegments.last}';");

  buffer.writeln(
      definitions.map((definition) => queryConstructor(definition)).join('\n'));

  buildStep.writeAsString(
    queryId,
    buffer.toString(),
  );
}

String queryConstructor(TableDefinition definition) {
  final buffer = StringBuffer();
  // final columns = definition.columns;
  final table = definition.name;

  final tabCols =
      definition.columns.map((element) => "'${element.columnName}'").toList();

  buffer
    ..writeln('class ${table}Query{')
    ..writeln('${table}Query();')
    ..writeln(
      'factory ${table}Query.referenced({required List<Join> joins})=>${table}Query().._joins.addAll(joins);',
    )
    // ..writeln('String? _byTable;')
    // ..writeln('String? _onColumn;')
    ..writeln("static const table='$table';")
    ..writeln(
      "TextColumn get id => TextColumn(column:'id',offtable:'$table',depends:_joins);",
    );
  // ..writeln(
  //   'factory ${definition.name}Query.referenced({required List<Join> joins})=>${definition.name}Query().._joins.addAll(joins);',
  // );

  final types = {
    ColumnsDataType.bigInt: 'NumberColumn',
    ColumnsDataType.int: 'NumberColumn',
    ColumnsDataType.integer: 'NumberColumn',
    ColumnsDataType.smallInt: 'NumberColumn',
    ColumnsDataType.bigSerial: 'NumberColumn',
    ColumnsDataType.doublePrecision: 'NumberColumn',
    ColumnsDataType.decimal: 'NumberColumn',
    ColumnsDataType.real: 'NumberColumn',
    ColumnsDataType.uuid: 'TextColumn',
    ColumnsDataType.char: 'TextColumn',
    ColumnsDataType.varchar: 'TextColumn',
    ColumnsDataType.text: 'TextColumn',
    ColumnsDataType.cidr: 'TextColumn',
    ColumnsDataType.inet: 'TextColumn',
    ColumnsDataType.date: 'DateTimeColumn',
    ColumnsDataType.datetz: 'DateTimeColumn',
    ColumnsDataType.time: 'DateTimeColumn',
    ColumnsDataType.timetz: 'DateTimeColumn',
    ColumnsDataType.timestamp: 'DateTimeColumn',
    ColumnsDataType.timestamptz: 'DateTimeColumn',
    ColumnsDataType.boolean: 'BooleanColumn',
  };

  for (final column in definition.columns) {
    if (column.references == null) {
      buffer.writeln(
          '${types[column.dbType]} get ${column.name} => ${types[column.dbType]}(column:"${column.columnName}",offtable:"$table",depends:_joins);');
    } else {
      buffer.writeln(
          '${column.references}Query get ${column.name}=> ${column.references}Query.referenced(joins:[Join(table:"${column.references}",from:"$table",onn:"${definition.tableName}.id=${column.references}")]);');
    }
  }
  buffer
    // ..writeln('final _joins=<Join>[${joins.join(",")}];')
    ..writeln('final _joins=<Join>[];')
    ..writeln('static List<String> get columns=> <String>$tabCols;')
    ..writeln('}');
  return buffer.toString();
}
