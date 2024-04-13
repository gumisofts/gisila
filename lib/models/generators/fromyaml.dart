import 'dart:async';
import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';
import 'package:yaml/yaml.dart';

final toDartOpMap = {
  'text': 'String',
  'timestamp': 'DateTime',
  'integer': 'int',
  'int': 'int',
  'boolean': 'bool',
  'varchar': 'String',
  'real': 'double',
};
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
// String? getFieldType(YamlMap column, String typ) {
//   final tt = typ.toLowerCase().trim();
//   if (tt == 'foreignkey') {
//     return column['references'] as String?;
//   }

//   return toDartOpMap[tt];
// }

String fieldType(dynamic column) {
  String? type;
  if (column.value is String) {
    type = toDartOpMap[column.value.toLowerCase()];

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

// dynamic getDefault(String typ, dynamic value) {
//   if (typ.toLowerCase().trim() == 'text') {
//     return "'$value'";
//   }

//   return value;
// }

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
        '.yaml': ['.dart', '.sql', '.drop.sql', '.query.g.dart'],
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
      // final def = defaultValueWrapper(column.value['default']);

      // unique ??= false;

      if (!pgTypes.contains(typ!.toLowerCase())) {
        throw Exception('type $typ is not Valid DataType for postgress');
      }

      if (typ.toLowerCase() == 'foreignkey') {
        typ = 'integer';
        foreign.add({
          'ref1': entry.key.toLowerCase(),
          'column': column.key,
          'ref2': column.value['references'].toLowerCase(),
        });
      }
      if (unique) {
        uniqueCon.add(
          {
            'table': entry.key.toString().toLowerCase(),
            'column': column.key,
          },
        );
      }
      sqlBuffer.writeln(
        ',"${column.key}" $typ ${isnull ? '' : "not null"} ${def == null ? "" : "default ${defaultValueWrapper(def)}"}',
      );
    }
    sqlBuffer.writeln(');');
  }
  // right constraints
  for (final item in foreign) {
    sqlBuffer.writeln(
      'ALTER TABLE "${item['ref1']}" ADD CONSTRAINT ${item['ref1']}_${item['column']}_${item['ref2']}_fk FOREIGN KEY ("${item['column']}") REFERENCES "${item['ref2']}" ("${item['ref2'].toLowerCase()}Id");',
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
        "NumberColumn get id => NumberColumn(column:'${entry.key.toLowerCase()}Id',offtable:'$table');",
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
          ? "${col.value['references']}Query get ${col.key} => ${col.value['references']}Query.referenced(joins:[..._joins,Join(table: '${col.value['references'].toLowerCase()}', onn: '${col.key}', from: table),]);"
          : ['int', 'integer', 'real'].contains(typ.toLowerCase())
              ? "NumberColumn get ${col.key}=> NumberColumn(column:'$column',offtable:'$table',depends: _joins);"
              : "TextColumn get ${col.key}=> TextColumn(column:'$column',offtable:'$table',depends: _joins);";
      if (typ.toLowerCase() == 'foreignkey') {
        joins.add(
          'Join(table: "${col.value['references'].toLowerCase()}",onn:"${col.key}",from:"${entry.key.toLowerCase()}")',
        );
      }
      {
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
  final inId = buildStep.inputId;
  final cId = inId.changeExtension('.dart');
  final partId = cId.changeExtension('.g.dart');
  final queryId = cId.changeExtension('.query.g.dart');
  buffer
    ..writeln("import 'package:json_annotation/json_annotation.dart';")
    ..writeln("import 'package:project_mega/database/database.dart';")
    ..writeln("import 'package:postgres/postgres.dart';")
    ..writeln("part '${partId.pathSegments.last}';")
    ..writeln("part '${queryId.pathSegments.last}';");

  for (final entry in map.entries) {
    final columns = entry.value['columns'] as YamlMap;

    buffer
      ..writeln('@JsonSerializable()')
      ..writeln('class ${entry.key}{');
    final reqFields = <String>[];
    final fields = <String, String>{};

    // Write Custome fields
    buffer
      ..writeln('int? _${entry.key.toLowerCase()}Id;')
      ..writeln('int? get id=>_${entry.key.toLowerCase()}Id;');

    //Write model class fields reading from YamlMap
    for (final col in columns.entries) {
      String? typ;
      var isnull = true;
      final ftype =
          fieldType(col); // get Dart Data type based on Postgress data types
      final def = defaultValue(col.value);
      if (col.value is String) {
        typ = col.value as String;
      } else {
        isnull = (col.value['isnull'] as bool?) ?? true;
        typ = col.value['type'] as String?;
      }
      if (typ == null) {
        continue;
      }
      if (!isnull && def == null) {
        reqFields.add(col.key as String);
      }
      fields[col.key as String] = fieldType(col);

      buffer.writeln(
        '$ftype ${col.key}${def == null ? '' : '= $def'};',
      );
    }

// write Constructors
    if (reqFields.isNotEmpty) {
      buffer
        ..writeln('${entry.key}({')
        ..writeln(reqFields.map((e) => 'required this.$e').join(','))
        ..writeln('});');
    } else {
      buffer.writeln('${entry.key}();');
    }
    buffer
      ..writeln(
        "static String table='${entry.key.toString().toLowerCase()}';",
      )
      ..writeln('factory ${entry.key}.fromRow(ResultRow row){')
      ..writeln('final map=row.toColumnMap();')
      ..writeln('return ${entry.key}(')
      ..writeln(
        reqFields
            .map(
              (e) => dartTypes.contains(fields[e])
                  ? "$e:map['$e'] as ${fields[e]}"
                  : '$e:${fields[e]}.fromRow(row)',
            )
            .join(','),
      )
      ..writeln(')')
      ..writeln(
        ".._${entry.key.toLowerCase()}Id= map['${entry.key.toLowerCase()}Id'] as int?",
      )
      ..writeln(
        fields.isEmpty
            ? ''
            : '..${fields.keys.map((e) => dartTypes.contains(fields[e]) ? "$e= (map['$e'] as ${fields[e]})" : "$e=${fields[e]}.fromRow(row)").join('..')}',
      )
      ..writeln(';')
      ..writeln('}')
      ..writeln('static Iterable<${entry.key}> fromResult(Result result)')
      ..writeln('=> result.map(${entry.key}.fromRow);')
      ////////////////////// Start Create //////////////////////////
      ..writeln(
        'static Future<${entry.key}?> create(${entry.key} ${entry.key.toLowerCase()}) async {',
      )
      ..writeln('final json=${entry.key.toLowerCase()}.toJson();')
      ..writeln('final conn = await Database().connection;')
      ..writeln('final query = Query.insert(table: table, columns: json);')
      ..writeln('final result = await conn.runTx((session) {')
      ..writeln('return session.execute(query.toString());')
      ..writeln('});')
      ..writeln(
        'return result.isEmpty ? null : ${entry.key}.fromRow(result.first);',
      )
      ..writeln('}')
      ///////////////////////// End of Creata /////////////////////////
      ///////////////////////// Start Filter//////////////////////////
      ..writeln(
        'static Future<Iterable<${entry.key}>> filter({required Operation? Function(${entry.key}Query) where})async{',
      )
      ..writeln('final tt = where(${entry.key}Query());')
      ..writeln('final query=Query.select(')
      ..writeln('table: ${entry.key}Query.table,')
      ..writeln('columns: ${entry.key}Query.columns,')
      ..writeln('operation: tt,')
      ..writeln('joins: tt==null?[]:tt.joins,')
      ..writeln(');')
      ..writeln('final conn = await Database().connection;')
      ..writeln('final result = await conn.execute(query.toString());')
      ..writeln('return fromResult(result);')
      ..writeln('}')
      ////////////////////////// End Filter ////////////////////////////
      ..writeln(
        'static ${entry.key} fromJson(Map<String, dynamic> json) => _\$${entry.key}FromJson(json);',
      )
      ..writeln(
        'Map<String, dynamic> toJson() => _\$${entry.key}ToJson(this);',
      )
      ..writeln('}');
    //////////////////////// Save //////////////////////////////////
  }
  final unformated = buffer.toString();
  final formatted = DartFormatter().format(unformated);
  await buildStep.writeAsString(cId, formatted);
}
