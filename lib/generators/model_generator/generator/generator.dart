import 'dart:async';

import 'package:build/build.dart';
import 'package:pg_dorm/database/postgres/definitions/table_definition.dart';
import 'package:pg_dorm/generators/model_generator/generator/model_db_generator.dart';
import 'package:pg_dorm/generators/model_generator/generator/models_generator.dart';
import 'package:pg_dorm/generators/model_generator/generator/query_generator.dart';
import 'package:yaml/yaml.dart';

class FromYamlGenerator extends Builder {
  @override
  FutureOr<void> build(BuildStep buildStep) async {
    final inputId = buildStep.inputId;

    final schema = parseSchema(buildStep);

    final tableDefinitions = await parseSchemaToTableDefinitions(buildStep);

    print(tableDefinitions);

    await modelsGenerator([], buildStep);

    await queryGenerator([], buildStep);

    await modelDbGenerator([], buildStep);

    // await
  }

  @override
  Map<String, List<String>> get buildExtensions => {
        '.yml': ['.dart', '.sql', '.drop.sql', '.query.g.dart', '.db.g.dart'],
        '.yaml': ['.dart', '.sql', '.drop.sql', '.query.g.dart', '.db.g.dart'],
      };

  Future<Map<String, dynamic>> parseSchema(BuildStep buildStep) async {
    final schemaFile = await buildStep.readAsString(buildStep.inputId);
    final yamlMap = loadYaml(schemaFile) as YamlMap;

    return parseSchemaFromYamlToJson(yamlMap);
  }

  Future<List<TableDefinition>> parseSchemaToTableDefinitions(
    BuildStep buildStep,
  ) async {
    // final schemaFile = await buildStep.readAsString(buildStep.inputId);
    // final schema = loadYaml(schemaFile) as YamlMap;

    final schema = await parseSchema(buildStep);

    return schema.entries
        .map((entry) => TableDefinition.fromYamlMap(entry))
        .toList();
  }

  dynamic parseSchemaFromYamlToJson(dynamic yaml) {
    if (yaml is YamlMap) {
      return yaml.map(
        (key, value) =>
            MapEntry(key.toString(), parseSchemaFromYamlToJson(value)),
      );
    } else if (yaml is YamlList) {
      return yaml.map(parseSchemaFromYamlToJson).toList();
    } else {
      return yaml;
    }
  }
}
