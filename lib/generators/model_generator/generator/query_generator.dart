import 'package:build/build.dart';
import 'package:pg_dorm/database/postgres/definitions/table_definition.dart';

Future<void> queryGenerator(
  List<TableDefinition> definitions,
  BuildStep buildStep,
) async {
  final buffer = StringBuffer();
  final queryId = buildStep.inputId.changeExtension('.query.g.dart');
  // final partOf = buildStep.inputId.changeExtension('.g.dart');
  final partId = buildStep.inputId.changeExtension('.dart');

  buffer.writeln("part of '${partId.pathSegments.last}';");

  buildStep.writeAsString(
    queryId,
    buffer.toString(),
  );
}
