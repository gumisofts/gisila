import 'dart:async';
import 'package:build/build.dart';
import 'package:d_orm/database/types.dart';
import 'package:dart_style/dart_style.dart';
import 'package:yaml/yaml.dart';

final toDartOpMap = TypeAdapter();
final dartTypes = [
  'String',
  'DateTime',
  'int',
  'bool',
  'double',
  'String?',
  'DateTime?',
  'int?',
  'bool?',
  'double?',
];
final pgTypes = [
  'real',
  'timestamp',
  'int',
  'integer',
  'text',
  'boolean',
  'foreignkey',
];
String fieldType(dynamic column) {
  String? type;
  if (column.value is String) {
    type = toDartOpMap[column.value.toLowerCase()]!.dart;

    if (type == null) {
      throw Exception(
        'Specify known type for the column ${column.key}: specified=>${column.value} ',
      );
    }

    return '$type?';
  }

  type = column.value['type'] as String;

  final isnull = column.value['isnull'] as bool? ?? true;

  if (type.toLowerCase() == 'foreignkey') {
    final foreign = column.value['references'] as String?;
    if (foreign == null) {
      throw Exception('Specify Referenced model for column ${column.key}');
    }
    return '$foreign${isnull ? '?' : ''}';
  }
  final dt = toDartOpMap[type.toLowerCase()];

  if (dt == null) {
    throw Exception('Unknown data type for column ${column.key}');
  }
  return '$dt${isnull ? '?' : ''}';
}

// String? dartFieldType(dynamic column){

// }
dynamic defaultValue(dynamic column) {
  if (column is String) return null;

  final type = column['type'] as String;
  final def = column['default'];
  if (type == 'text') {
    return "'$def'";
  }
  if (def.toString().toLowerCase() == 'datetime()') {
    return 'now()';
  }

  return def;
}

// TODO(nuradic): ForeignKey with reverse accessor,onDelete.
// TODO(nuradic): OneToOneField with reverse accesor,onDelete.
// TODO(nuradic): ManyToManyField with reverse accesor.

class ModelFromYamlBuilder implements Builder {
  @override
  FutureOr<void> build(BuildStep buildStep) async {
    final inId = buildStep.inputId;
    final content = await buildStep.readAsString(inId);
    final y = loadYaml(content) as YamlMap;
    await modelConstructor(y, buildStep);

    await queryConstructor(y, buildStep);

    await sqlConstructor(y, buildStep);
  }

  @override
  Map<String, List<String>> get buildExtensions => {
        '.yaml': ['.dart', '.sql', '.drop.sql', '.query.g.dart', '.db.g.dart'],
      };
}

String? defaultValueWrapper(dynamic typ) {
  if (typ is bool) {
    return typ.toString();
  }
  if (typ.toString().trim() == 'DateTime.now()') {
    return 'now()';
  }
  if (typ == null) return null;
  return "'$typ'";
}

Future<void> sqlConstructor(YamlMap map, BuildStep buildStep) async {
  final sqlId = buildStep.inputId.changeExtension('.sql');
  final drop = buildStep.inputId.changeExtension('.drop.sql');
  final sqlBuffer = StringBuffer();
  final foreign = <dynamic>[];
  final uniqueCon = <dynamic>[];
  final dropLines = <dynamic>[];
  sqlBuffer.writeln('BEGIN;');
  dropLines.add('COMMIT;');
  for (final entry in map.entries) {
    sqlBuffer
      ..writeln('Create Table If Not Exists"${entry.key.toLowerCase()}"(')
      ..writeln('"${entry.key.toLowerCase()}Id" SERIAL Primary Key');
    // dropBuffer.writeln('Drop Table ${entry.key};');

    dropLines
        .add('Drop Table If Exists "${entry.key.toString().toLowerCase()}";');

    final columns = entry.value['columns'] as YamlMap;

    for (final column in columns.entries) {
      String? typ;
      bool isFor = false;
      var isnull = true;
      var unique = false;

      final def = defaultValue(column.value);

      if (column.value is String) {
        typ = column.value as String;
      } else {
        typ = column.value['type'] as String?;
        isnull = (column.value['isnull'] as bool?) ?? true;
        unique = (column.value['unique'] as bool?) ?? false;
      }
      if (!pgTypes.contains(typ!.toLowerCase())) {
        throw Exception('type $typ is not Valid DataType for postgress');
      }

      if (typ.toLowerCase() == 'foreignkey') {
        typ = 'integer';
        isFor = true;

        foreign.add({
          'ref1': entry.key.toLowerCase(),
          'column': column.key,
          'ref2': column.value['references'].toLowerCase(),
          'onDelete':
              "on Delete ${column.value['onDelete']?.toLowerCase() ?? 'NO ACTION'}"
        });
      }
      if (unique) {
        uniqueCon.add(
          {
            'table': entry.key.toString().toLowerCase(),
            'column': "${column.key}${isFor ? 'Id' : ''}",
          },
        );
      }
      sqlBuffer.writeln(
        ',"${column.key}${isFor ? 'Id' : ''}" $typ ${isnull ? '' : "not null"} ${def == null ? "" : "default ${defaultValueWrapper(def)}"}',
      );
    }
    sqlBuffer.writeln(');');
  }
  // right constraints
  for (final item in foreign) {
    sqlBuffer.writeln(
      'ALTER TABLE "${item['ref1']}" ADD CONSTRAINT ${item['ref1']}_${item['column']}_${item['ref2']}_fk FOREIGN KEY ("${item['column']}Id") REFERENCES "${item['ref2']}" ("${item['ref2'].toLowerCase()}Id") ${item['onDelete']};',
    );

    dropLines.add(
      'Alter Table IF Exists "${item['ref1']}" DROP Constraint If Exists ${item['ref1']}_${item['column']}_${item['ref2']}_fk;',
    );
  }
  // Unique constraints

  for (final item in uniqueCon) {
    sqlBuffer.writeln(
      'ALTER TABLE "${item['table']}" ADD CONSTRAINT ${item['table']}_${item['column']}_unique UNIQUE ("${item['column']}");',
    );
    dropLines.add(
      'Alter Table If Exists "${item['table']}" Drop Constraint If Exists ${item['table']}_${item['column']}_unique;',
    );
  }
  sqlBuffer.writeln('COMMIT;');
  dropLines.add('BEGIN;');
  await buildStep.writeAsString(drop, dropLines.reversed.join('\n'));
  await buildStep.writeAsString(sqlId, sqlBuffer.toString());
}

Future<void> queryConstructor(YamlMap map, BuildStep buildStep) async {
  final buffer = StringBuffer();
  final cid = buildStep.inputId.changeExtension('.query.g.dart');
  final partOf = buildStep.inputId.changeExtension('.dart');

  buffer.writeln("part of '${partOf.pathSegments.last}';");
  for (final entry in map.entries) {
    final columns = entry.value['columns'] as YamlMap;
    final table = entry.key.toString().toLowerCase();
    buffer
      ..writeln('class ${entry.key}Query{')
      ..writeln('${entry.key}Query();')
      ..writeln(
        'factory ${entry.key}Query.referenced({required List<Join> joins})=>${entry.key}Query().._joins.addAll(joins);',
      )
      // ..writeln('String? _byTable;')
      // ..writeln('String? _onColumn;')
      ..writeln("static const table='$table';")
      ..writeln(
        "NumberColumn get id => NumberColumn(column:'${entry.key.toLowerCase()}Id',offtable:'$table',depends:_joins);",
      );
    final joins = <String>[];
    final tabCols = <String>["'${entry.key.toLowerCase()}Id'"];
    for (final col in columns.entries) {
      // final typ = col.value['type'] as String?;
      String? typ;

      // final ftype = fieldType(col);

      final column = col.key;

      if (col.value is String) {
        typ = col.value as String?;
      } else {
        typ = col.value['type'] as String?;
      }

      if (typ == null) {
        continue;
      }

      final colQuery = typ.toLowerCase() == 'foreignkey'
          ? "${col.value['references']}Query get ${col.key} => ${col.value['references']}Query.referenced(joins:[..._joins,Join(table: '${col.value['references'].toLowerCase()}', onn: '${col.key}Id', from: table),]);\n NumberColumn get ${col.key.toLowerCase()}Id=>NumberColumn(column:'${column}Id',offtable:'$table',depends: _joins);"
          : ['int', 'integer', 'real'].contains(typ.toLowerCase())
              ? "NumberColumn get ${col.key}=> NumberColumn(column:'$column',offtable:'$table',depends: _joins);"
              : "TextColumn get ${col.key}=> TextColumn(column:'$column',offtable:'$table',depends: _joins);";
      if (typ.toLowerCase() == 'foreignkey') {
        joins.add(
          'Join(table: "${col.value['references'].toLowerCase()}",onn:"${col.key}Id",from:"${entry.key.toLowerCase()}")',
        );
        tabCols.add("'${col.key.toLowerCase()}Id'");
      } else {
        tabCols.add("'${col.key}'");
      }
      buffer.writeln(colQuery);
    }

    buffer
      // ..writeln('final _joins=<Join>[${joins.join(",")}];')
      ..writeln('final _joins=<Join>[];')
      ..writeln('static List<String> get columns=> <String>$tabCols;')
      ..writeln('}');
  }

  await buildStep.writeAsString(cid, DartFormatter().format(buffer.toString()));
}

Future<void> modelConstructor(YamlMap map, BuildStep buildStep) async {
  final buffer = StringBuffer();
  final partBf = StringBuffer();
  final inId = buildStep.inputId;
  final cId = inId.changeExtension('.dart');
  final partId = cId.changeExtension('.db.g.dart');
  final queryId = cId.changeExtension('.query.g.dart');
  buffer
    ..writeln("import 'package:json_annotation/json_annotation.dart';")
    ..writeln("import 'package:d_orm/d_orm.dart';")
    ..writeln("part '${partId.pathSegments.last}';")
    ..writeln("part '${queryId.pathSegments.last}';");

  partBf.writeln("part of 'schema.dart';");
  final models = <Model>[];
  for (final schema in map.entries) {
    models.add(writeModel(schema));
    buffer.writeln(
        writeModel(schema)); // TODO(nuradic) Dont forget to remove this line:
    partBf.writeln(db(schema));
  }
  final unformated = buffer.toString();
  final formatted = DartFormatter().format(unformated);
  await buildStep.writeAsString(cId, formatted);
  await buildStep.writeAsString(
      partId, DartFormatter().format(partBf.toString()));
}

// PG_Handler

Model writeModel(dynamic schema) {
  // final buffer = StringBuffer();

  final model = Model(name: schema.key, columns: []);

  for (var col in schema.value['columns'].entries) {
    final type = col.value is String ? col.value : col.value['type'];
    final isnull =
        col.value is String ? true : (col.value['isnull'] as bool?) ?? true;
    final defValue = col.value is String ? null : col.value['default'];
    final unique =
        col.value is String ? false : (col.value['unique'] as bool?) ?? false;
    print('${col.key} ${schema.key} $type $defValue $isnull');
    if (col.value is! String &&
        col.value['type'].toString().toLowerCase() == 'foreignkey') {
      model.foreign = [
        ...model.foreign,
        ForeignColumn(
          name: col.key,
          reference: col.value['references'],
          isnull: isnull,
          unique: unique,
          defValue: defValue,
        )
      ];
      continue;
    }
    model.columns = [
      ...model.columns,
      Column(
        type: TypeAdapter()[type]!,
        name: col.key,
        unique: unique,
        isnull: isnull,
        defValue: defValue.toString(),
      )
    ];
  }

  return model;
}

String db(dynamic schema) {
  final bf = StringBuffer();
  final model = Model(name: schema.key, columns: []);
  for (var col in schema.value['columns'].entries) {
    final type = col.value is String ? col.value : col.value['type'];
    final isnull =
        col.value is String ? true : (col.value['isnull'] as bool?) ?? true;
    final defValue = col.value is String ? null : col.value['default'];
    final unique =
        col.value is String ? false : (col.value['unique'] as bool?) ?? false;
    print('${col.key} ${schema.key} $type $defValue $isnull');
    if (col.value is! String &&
        col.value['type'].toString().toLowerCase() == 'foreignkey') {
      model.foreign = [
        ...model.foreign,
        ForeignColumn(
          name: col.key,
          reference: col.value['references'],
          isnull: isnull,
          unique: unique,
          defValue: defValue,
        )
      ];
      continue;
    }
    model.columns = [
      ...model.columns,
      Column(
        type: TypeAdapter()[type]!,
        name: col.key,
        unique: unique,
        isnull: isnull,
        defValue: defValue.toString(),
      )
    ];
  }
  bf
    ..writeln('extension ${schema.key}Db on ${schema.key}{')
    ..writeln(model.toJson)
    ..writeln(model.fromResult)
    ..writeln(model.create)
    ..writeln(model.delete)
    ..writeln(model.filter)
    ..writeln(model.getIt)
    ..writeln('}');
  return bf.toString();
}
