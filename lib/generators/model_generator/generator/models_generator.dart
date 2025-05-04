import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';
import 'package:pg_dorm/database/postgres/data_types/mappings.dart';
import 'package:pg_dorm/database/postgres/definitions/column_definitions.dart';
import 'package:pg_dorm/database/postgres/definitions/table_definition.dart';

Future<void> modelsGenerator(
  List<TableDefinition> definitions,
  BuildStep buildStep,
) async {
  final buffer = StringBuffer();
  final partId = buildStep.inputId.changeExtension('.db.g.dart');
  final queryId = buildStep.inputId.changeExtension('.query.g.dart');

  buffer
    ..writeln("import 'package:pg_dorm/pg_dorm.dart';")
    ..writeln("part '${partId.pathSegments.last}';")
    ..writeln("part '${queryId.pathSegments.last}';");

  buffer.writeln(
      definitions.map((definition) => modelGenerator(definition)).join('\n'));

  buildStep.writeAsString(
    buildStep.inputId.changeExtension('.dart'),
    DartFormatter().format(buffer.toString()),
  );
}

String modelGenerator(TableDefinition definition) {
  final buffer = StringBuffer();

  buffer.writeln('class ${definition.name}{');

  for (var column in definition.columns) {
    buffer.writeln(modelsFieldGenerator(column));
  }

  buffer
    ..writeln(modelsConstructor(definition))
    ..writeln('}');

  return buffer.toString();
}

String modelsConstructor(TableDefinition definition) {
  final buffer = StringBuffer();

  buffer.writeln('${definition.name}({');

  final assigned = <String>[];

  for (var column in definition.columns) {
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

    assigned.add('_${column.name}=${column.name};');
  }

  buffer.writeln("}){");

  buffer.writeln(assigned.join('\n'));

  buffer.writeln(methodsGenerator(definition));

  buffer.writeln('}');

  return buffer.toString();
}

String modelsFieldGenerator(BaseColumnDefinition definition) {
  final buffer = StringBuffer();

  if (definition.references == null) {
    buffer.writeln(
        '${getDartType(definition.dbType.type)}${definition.isNull ? "?" : ""} get ${definition.name}=>_${definition.name};');
    buffer.writeln(
        'set ${definition.name}(${getDartType(definition.dbType.type)}${definition.isNull ? "?" : ""} ${definition.name})=>_${definition.name}=${definition.name};');
    buffer.writeln(
        'late ${getDartType(definition.dbType.type)}${definition.isNull ? "?" : ""} _${definition.name};');
  } else if (definition.isManyToManyReferences) {
    buffer
      ..writeln(
          "late Iterator<${definition.references}>${definition.isNull ? "?" : ""} _${definition.name};")
      ..writeln("")
      ..writeln(
          "Iterator<${definition.references}>${definition.isNull ? "?" : ""} get ${definition.name}=>_${definition.name};")
      ..writeln(
          "set ${definition.name}(Iterator<${definition.references}>${definition.isNull ? "?" : ""} ${definition.name})=>_${definition.name}=${definition.name};");
  } else {
    buffer.writeln(
        "${definition.references}${definition.isNull ? "?" : ""}  get ${definition.name}=>_${definition.name};");
    buffer
      ..writeln(
          'late ${definition.references}${definition.isNull ? "?" : ""}  _${definition.name};')
      ..writeln(
          "set ${definition.name}(${definition.references}${definition.isNull ? "?" : ""} ${definition.name})=>_${definition.name}=${definition.name};");
  }

  return buffer.toString();
}

String methodsGenerator(TableDefinition definition) {
  final buffer = StringBuffer();

  buffer
    ..writeln('Future<void> save()async{}')
    ..writeln('Future<void> delete()=>${definition.name}Db.delete(this);');

  return buffer.toString();
}
