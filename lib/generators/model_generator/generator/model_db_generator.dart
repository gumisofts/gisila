import 'package:build/build.dart';
import 'package:pg_dorm/database/postgres/definitions/table_definition.dart';

Future<void> modelDbGenerator(
  List<TableDefinition> definitions,
  BuildStep buildStep,
) async {
  final buffer = StringBuffer();
  final dbId = buildStep.inputId.changeExtension('.db.g.dart');
  final partId = buildStep.inputId.changeExtension('.dart');

  buffer.writeln("part of '${partId.pathSegments.last}';");

  buildStep.writeAsString(
    dbId,
    buffer.toString(),
  );
}
