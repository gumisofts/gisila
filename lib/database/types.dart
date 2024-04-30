import 'package:d_orm/database/exceptions.dart';
import 'package:d_orm/database/extensions.dart';

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
    return TypeAdapter._types
        .firstWhere((element) => element.pg == index.toLowerCase().trim());
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
            msg: "Not Valid default value for dateTime");
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
            msg: "Invalid Default value for double type");
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
      ..writeln('${isnull ? '' : 'late'} int${isnull ? '?' : ''} _${name}Id;')
      ..writeln("int${isnull ? '?' : ''} get ${name}Id=>_${name}Id;")
      ..writeln('set ${name}Id(int${isnull ? '?' : ''}  id) {')
      ..writeln('_updatedFields["$name"]=id;')
      ..writeln('_${name}Id=id;')
      ..writeln('}')
      ..writeln('ModelHolder<$reference>? _get$name;')
      ..writeln('Future<$reference?> get $name {')
      ..writeln(
          '_get$name??=ModelHolder<$reference>(getModelInstance:()=> ${reference}Db.get(where:(t)=>t.id.equals(${name}Id${isnull ? "!" : ''})));')
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
          '${isnull ? '' : 'late'} ${type.dart}${isnull ? '?' : ''} _$name;')
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

class Model {
  Model({
    required this.name,
    required this.columns,
    this.indexes = const [],
    this.foreign = const [],
  });
  String name;
  List<Column> columns;
  List<ForeignColumn> foreign;
  List<Index> indexes;
  String get deleteMe {
    final bf = StringBuffer()
      ..writeln('Future<bool> delete()async{')
      ..writeln('return ${name}Db.delete(this);')
      ..writeln('}');

    return bf.toString();
  }

  String get filter {
    final bf = StringBuffer()
      ..writeln(
          'static Future<Iterable<$name>> filter({required Operation? Function(${name}Query) where,List<String> orderBy = const [],int offset=0,int? limit,List<Join>joins=const [],})async{')
      ..writeln('final tt = where(${name}Query());')
      ..writeln('final query=Query.select(')
      ..writeln('table: ${name}Query.table,')
      ..writeln('columns: ${name}Query.columns,')
      ..writeln('operation: tt,')
      ..writeln('offset:offset,')
      ..writeln('limit:limit,')
      ..writeln('joins: tt==null?[]:tt.joins,')
      ..writeln(');')
      // ..writeln('..offset(offset);')
      // ..writeln('if(limit!=null)query.limit(limit);')
      ..writeln('final result = await Database.execute(query.toString());')
      ..writeln('return fromResult(result);')
      ..writeln('}');

    return bf.toString();
  }

  String get toJson {
    final bf = StringBuffer()
      ..writeln(
          'Map<String,dynamic> toJson({bool excludeNull=false,List<String>? exclude,List<String>?only}){')
      ..writeln('final json= {')
      ..writeln("'id':id,")
      ..writeln(columns.map((e) => e.toMap).join())
      ..writeln(foreign.map((e) => e.toMap).join())
      ..writeln('};')
      ..writeln('if(excludeNull){')
      ..writeln('json.removeWhere((key,value)=>value==null);')
      ..writeln('}')
      ..writeln('if(only!=null){')
      ..writeln('json.removeWhere((key, value) => !only.contains(key));')
      ..writeln('}')
      ..writeln('else if(exclude!=null){')
      ..writeln('json.removeWhere((key,value)=>exclude.contains(key));')
      ..writeln('}')
      ..writeln('return json;')
      ..writeln('}');

    return bf.toString();
  }

  String get fromResult {
    final bf = StringBuffer()
      ..writeln('static $name fromRow(ResultRow row){')
      ..writeln('final map=row.toColumnMap();')
      ..writeln('return')
      ..writeln(name)
      ..writeln('(')
      ..writeln('id: map["${name.toLowerCase()}Id"] as int,')
      ..writeln(
        columns
            .where((element) => !element.isnull)
            .map((e) => '${e.name}: map["${e.name}"] as ${e.type.dart},')
            .join(''),
      )
      ..writeln(
        columns
            .where((element) => element.isnull)
            .map((e) => '${e.name}: map["${e.name}"] as ${e.type.dart}?,')
            .join(''),
      )
      ..writeln(
        foreign
            .where((element) => !element.isnull)
            .map((e) => '${e.name}Id: map["${e.name}Id"] as int,')
            .join(''),
      )
      ..writeln(
        foreign
            .where((element) => element.isnull)
            .map((e) => '${e.name}Id: map["${e.name}Id"] as int?,')
            .join(''),
      )
      ..writeln(');')
      ..writeln('}')
      ..writeln('static Iterable<$name> fromResult(Result result){')
      ..writeln('return result.map(fromRow);')
      ..writeln('}');

    return bf.toString();
  }

  String get getIt {
    final bf = StringBuffer()
      ..writeln(
          'static Future<$name?> get({required Operation Function(${name}Query) where})async{')
      ..writeln('final res=await filter(where:where);')
      ..writeln('if(res.isEmpty)return null;')
      ..writeln('return res.first;')
      ..writeln('}');

    return bf.toString();
  }

  String get create {
    final bf = StringBuffer()
      ..writeln('static Future<$name> create({')
      ..writeln(
        columns
            .where((element) => !element.isnull)
            .map((e) => e.forNamed)
            .join(''),
      )
      ..writeln(foreign.map((e) => e.forNamed).join(''))
      ..writeln(columns
          .where((element) => element.isnull)
          .map((e) => e.forNamed)
          .join(''))
      ..writeln('})async{')
      ..writeln('final model= $name(')
      ..writeln(columns.map((e) => '${e.name}:${e.name},').join('\n'))
      ..writeln(foreign.map((e) => '${e.name}Id:${e.name}Id,').join('\n'))
      ..writeln(');')
      ..writeln('final data = model.toJson(excludeNull:true);')
      ..writeln('final q= Query.insert(')
      ..writeln("table: '${name.toLowerCase()}',")
      ..writeln('columns: data,')
      ..writeln(');')
      // ..writeln('try{')
      ..writeln('final res=await Database.execute(q.toString());')
      ..writeln('return fromRow(res.first);')
      // ..writeln('}catch(_){')
      // ..writeln('return null;')
      // ..writeln('}')
      ..writeln('}')
      ..writeln();

    return bf.toString();
  }

  String get delete {
    final bf = StringBuffer()
      ..writeln('static Future<bool> delete($name ${name.toLowerCase()})async{')
      ..writeln('final q=Query.delete(')
      ..writeln('table: "${name.toLowerCase()}",')
      ..writeln(
          "operation: Operation('${name.toLowerCase()}Id'.safeTk,Operator.eq,${name.toLowerCase()}.id),")
      ..writeln(');')
      ..writeln('try{')
      ..writeln('await Database.execute(q.toString());')
      ..writeln('return true;')
      ..writeln('}catch(_){')
      ..writeln('return false;')
      ..writeln("}")
      ..writeln('}');

    return bf.toString();
  }

  String get save {
    final bf = StringBuffer()
      ..writeln('static Future<void> save($name ${name.toLowerCase()})async{')
      ..writeln('')
      ..writeln('}');
    return bf.toString();
  }

  String get saveMe {
    final bf = StringBuffer()
      ..writeln('Future<void> save()async{')
      ..writeln('if(_updatedFields.isNotEmpty){')
      ..writeln('final query=Query.update(')
      ..writeln('table: "${name.toLowerCase()}",')
      ..writeln('columns: _updatedFields,')
      ..writeln(
          'operation: Operation("${name.toLowerCase()}Id".safeTk,Operator.eq,id),')
      ..writeln(');')
      ..writeln('await Database.execute(query.toString());')
      ..writeln('}')
      ..writeln('}');
    return bf.toString();
  }

  @override
  String toString() {
    final bf = StringBuffer()
      ..writeln("class $name{")
      ..writeln('$name ({')
      ..writeln(
        columns
            .where((element) => !element.isnull)
            .map((e) => e.forNamed)
            .join(''),
      )
      ..writeln(foreign.map((e) => e.forNamed).join(''))
      ..writeln('this.id,')
      ..writeln(columns
          .where((element) => element.isnull)
          .map((e) => e.forNamed)
          .join(''))
      ..writeln('}){')
      ..writeln(columns.map((e) => '_${e.name}=${e.name};').join('\n'))
      ..writeln(foreign.map((e) => '_${e.name}Id=${e.name}Id;').join('\n'))
      ..writeln('}')
      ..writeln(foreign.map((e) => e.toString()).join(''))
      ..writeln('final _updatedFields = <String,dynamic>{};')
      ..writeln('int? id;')
      ..writeln(saveMe)
      ..writeln(deleteMe)
      ..writeln(columns.map((e) => e.toString()).join())
      ..writeln("}");
    return bf.toString();
  }
}

// void main(List<String> args) {
//   try {} catch (_) {}
//   final cc =
//       Column(type: TypeAdapter()['text']!, name: 'firstName', isnull: false);
//   final bb = Model(name: 'User', columns: [
//     Column(type: TypeAdapter()['text']!, name: 'firstName'),
//     Column(type: TypeAdapter()['int']!, name: 'age'),
//   ]);

//   print(DartFormatter().format(bb.toString()));
// }
