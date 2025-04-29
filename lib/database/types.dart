import 'package:pg_dorm/database/postgres/exceptions.dart';
import 'package:pg_dorm/database/extensions.dart';

class TypeAdapter {
  String? dart;
  String? pg;
  TypeAdapter({this.dart, this.pg});

  static List<TypeAdapter> get _types => [
        TypeAdapter(dart: "String", pg: "text"),
        TypeAdapter(dart: "int", pg: "integer"),
        TypeAdapter(dart: "int", pg: "int"),
        TypeAdapter(dart: "bool", pg: "boolean"),
        TypeAdapter(dart: "double", pg: "real"),
        TypeAdapter(dart: "DateTime", pg: "timestamp"),
      ];

  TypeAdapter? operator [](String index) {
    return TypeAdapter._types.firstWhere(
      (element) => element.pg == index.toLowerCase().trim(),
    );
  }
}

class DefaultEngine {
  String? dartdef;
  String? pgdef;
  static DefaultEngine? def = DefaultEngine._init();
  factory DefaultEngine() => def ?? DefaultEngine._init();

  DefaultEngine._init();
  String pgDef(String syn, type) {
    if (type is DateTime) {
      if (syn == "now" || syn == "every_now") {
        throw DefaultValueException(
          msg: "Not Valid default value for dateTime",
        );
      }
    }

    if (type is bool) {
      if (syn == 'false' || syn != 'true') {
        throw DefaultValueException(msg: "Invalid Default value for bool type");
      }
      return syn;
    }
    if (type is int) {
      if (!RegExp(r"\d+").hasMatch(syn)) {
        throw DefaultValueException(msg: "Invalid Default value for int type");
      }
      return syn;
    }
    if (type is double) {
      if (!RegExp(r"\d+\.?\d*").hasMatch(syn)) {
        throw DefaultValueException(
          msg: "Invalid Default value for double type",
        );
      }

      return syn;
    }

    return syn.safe;
  }
}

class Constraint {
  Constraint({required this.name});
  String name;
}

class ForeignColumn {
  ForeignColumn({
    required this.name,
    required this.reference,
    this.defValue,
    this.isnull = true,
    this.unique = false,
  });
  String name;
  bool isnull;
  String? defValue;
  bool unique;
  String reference;

  String get forNamed => "${isnull ? 'int?' : 'required int'} ${name}Id,";

  // String get classField {
  //   final bf = StringBuffer()
  //     ..writeln(toString())
  //     ..writeln(
  //         '$reference? $name=>ModelHolder<$reference>(getModelInstance: $reference.get(where:(t)=>t.id.equals(${name}Id)));');
  //   return bf.toString();
  // }
  String get toMap => "'${name}Id': ${name}Id,";

  @override
  String toString() {
    final bf = StringBuffer()
      ..writeln(
        '${isnull ? '' : 'late'} int${isnull ? '?' : ''} _${name}Id;',
      )
      ..writeln("int${isnull ? '?' : ''} get ${name}Id=>_${name}Id;")
      ..writeln('set ${name}Id(int${isnull ? '?' : ''}  id) {')
      ..writeln('_updatedFields["$name"]=id;')
      ..writeln('_${name}Id=id;')
      ..writeln('}')
      ..writeln('ModelHolder<$reference>? _get$name;')
      ..writeln('Future<$reference?> get $name {')
      ..writeln(
        '_get$name??=ModelHolder<$reference>(getModelInstance:()=> ${reference}Db.get(where:(t)=>t.id.equals(${name}Id${isnull ? "!" : ''})));',
      )
      ..writeln('return _get$name!.instance;')
      ..writeln('}');
    return bf.toString();
  }
}

class Column {
  Column({
    required this.type,
    required this.name,
    this.defValue,
    this.isnull = true,
    this.unique = false,
  });

  String name;
  TypeAdapter type;
  bool isnull;
  String? defValue;
  bool unique;

  String get toMap => type.dart != 'DateTime'
      ? "'$name': $name,"
      : "'$name': $name?.toIso8601String(),";

  String get forNamed =>
      "${isnull ? '' : 'required '}${type.dart}${isnull ? '?' : ''} $name,";

  @override
  String toString() {
    final bf = StringBuffer()
      ..writeln(
        '${isnull ? '' : 'late'} ${type.dart}${isnull ? '?' : ''} _$name;',
      )
      ..writeln('${type.dart}${isnull ? '?' : ''} get $name=> _$name;')
      ..writeln('set $name(${type.dart}${isnull ? '?' : ''}  m) {')
      ..writeln("_updatedFields['$name']=m;")
      ..writeln('_$name=m;')
      ..writeln('}');
    return bf.toString();
  }

  String toSqlString() {
    return "${name.safeTk} ${isnull && defValue == null ? '' : 'not null'} ${unique ? 'unique' : ''} ${defValue == null ? '' : DefaultEngine().pgDef(defValue!, type.dart)}";
  }
}

class Index {
  Index({required this.name, required this.onTable, required this.columns});
  String name;
  String onTable;
  List<Column> columns;

  @override
  String toString() =>
      "create index $name on ${onTable.safeTk} (${columns.map((e) => e.name).join(',')})";
}
