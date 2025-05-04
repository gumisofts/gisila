import 'package:build/build.dart';
import 'package:pg_dorm/database/postgres/data_types/mappings.dart';
import 'package:pg_dorm/database/postgres/definitions/table_definition.dart';

Future<void> modelsDbGenerator(
  List<TableDefinition> definitions,
  BuildStep buildStep,
) async {
  final buffer = StringBuffer();
  final dbId = buildStep.inputId.changeExtension('.db.g.dart');
  final partId = buildStep.inputId.changeExtension('.dart');

  buffer.writeln("part of '${partId.pathSegments.last}';");

  for (var definition in definitions) {
    buffer.writeln(modelDbGenerator(definition));
  }

  buildStep.writeAsString(dbId, buffer.toString()
      // DartFormatter().format(buffer.toString()),
      );
}

String modelDbGenerator(TableDefinition definition) {
  final buffer = StringBuffer();

  buffer.writeln('class ${definition.name}Db{');

  buffer
    ..writeln('static String table="${definition.name.toLowerCase()}";')
    ..writeln(modelMethodGenerator(definition));

  buffer.writeln('}');

  return buffer.toString();
}

String modelMethodGenerator(TableDefinition definition) {
  final buffer = StringBuffer();

  final assigned = <String>[];

  buffer.writeln('static Future<${definition.name}> create({');

  for (var column in definition.columns) {
    assigned.add('${column.name}:${column.name}');
    if (!column.isNull) {
      buffer.write('required ');
    }
    if (column.references == null) {
      buffer.writeln(
          "${getDartType(column.dbType.type)}${column.isNull ? "?" : ""} ${column.name},");
    } else if (column.isManyToManyReferences) {
      buffer.writeln(
          'Iterator<${column.references}>${column.isNull ? "?" : ""} ${column.name},');
    } else {
      buffer.writeln(
          '${column.references}${column.isNull ? "?" : ""} ${column.name},');
    }
  }

  buffer
    ..writeln("})async{")
    ..writeln('final columns=<String,dynamic>{');

  for (var column in definition.columns) {
    buffer.writeln('"${column.name}":${column.name},');
  }

  buffer.writeln('};');
  buffer.writeln('final query=Query.insert(table: table, columns: columns);');
  buffer
    ..writeln('return ${definition.name}(')
    ..writeln(assigned.join(','))
    ..writeln(");")
    ..writeln('}');

  buffer
    ..writeln(
        'static Future<void> delete(${definition.name} ${definition.name.toLowerCase()})')
    ..writeln("async{")
    ..writeln('}');
  return buffer.toString();
}
