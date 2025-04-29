import 'package:build/build.dart';
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

  buildStep.writeAsString(
    buildStep.inputId.changeExtension('.dart'),
    buffer.toString(),
  );
}
