import 'package:analyzer/dart/element/element.dart';
import 'package:build/src/builder/build_step.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:source_gen/source_gen.dart';

class ModelFromJsonAnnotation extends GeneratorForAnnotation<JsonSerializable> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    final buffer = StringBuffer();

    final className = element.displayName;
    final columns = element.children
        .where((element) => element.kind.toString() == 'SETTER')
        .map((e) => "'${e.displayName}'")
        .toList();

    buffer
      ..writeln('extension ${className}Ext on $className{')
      // ..writeln('int? id;')
      // ..writeln("static String table = '${className.toLowerCase()}';")
      // ..writeln('static List<String>get columns => $columns;')
      // ..writeln(
      //   'static Future<$className?> create($className ${className.toLowerCase()}) async {',
      // )
      // ..writeln('final json=_\$${className}ToJson(${className.toLowerCase()});')
      // ..writeln('final conn = await Database().connection;')
      // ..writeln('final query = Query.insert(table: table, columns: json);')
      // ..writeln('final result = await conn.runTx((session) {')
      // ..writeln('return session.execute(query.toString());')
      // ..writeln('});')
      // ..writeln(
      //   'return result.isEmpty ? null : _\$${className}FromRow(result.first);',
      // )
      // ..writeln('}')
      // ..writeln('static Future<int> count([Operation? op]) async {')
      // ..writeln('final conn = await Database().connection;')
      // ..writeln(
      //   'final query = Query.select(table: table, columns: columns, operation: op).count();',
      // )
      // ..writeln('final result = await conn.execute(query);')
      // ..writeln("return result.first.toColumnMap()['count'] as int;")
      // ..writeln('}')
      // ..writeln('Future<$className> update(Map<String, dynamic> json) async {')
      // ..writeln('if (id == null || json.isEmpty) return this;')
      // ..writeln('final conn = await Database().connection;')
      // ..writeln('final query = Query.update(')
      // ..writeln('table: table,')
      // ..writeln('columns: json,')
      // ..writeln("operation: Operation('id', Operator.eq, id),")
      // ..writeln(');')
      // ..writeln('final result = await conn.runTx((session) {')
      // ..writeln('return session.execute(query.toString());')
      // ..writeln('});')
      // ..writeln('return _\$${className}FromJson(result.first.toColumnMap());')
      // ..writeln('}')
      // ..writeln(
      //   'Map<String, dynamic> toJson() => _\$${className}ToJson(this);',
      // );
//     final filter = '''
// static Future<Iterable<$className>> filter([Operation? op]) async {
//     final conn = await Database().connection;

//     final query = Query.select(table: table, columns: columns, operation: op);

//     final result = await conn.execute(query.toString());

//     return result.map((element) => _\$${className}FromJson(element.toColumnMap()));
//   }
// ''';

      // buffer
      //   ..writeln(filter)
      //   ..writeln('static Future<Iterable<$className>> all() async => filter();');

//     const delete = '''
// Future<int> delete() async {
//     final conn = await Database().connection;
//     if (id == null) return -1;

//     final query = Query.delete(
//       table: table,
//       operation: Operation('id', Operator.eq, id),
//     );
//     final result = await conn.execute(query.toString());

//     return result.first.isEmpty ? -1 : id!;
//   }''';
//     buffer
//       ..writeln(delete)
      ..writeln('}');

    return buffer.toString();
  }
}
