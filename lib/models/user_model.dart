// import 'package:json_annotation/json_annotation.dart';
// import 'package:project_mega/database/database.dart';
// part 'user_model.g.dart';

// abstract class BaseUser {
//   BaseUser({
//     required String fname,
//     String? lname,
//     String? phone,
//     String? email,
//     String? password,
//   }) {
//     _email = email;
//     _fname = fname;
//     _phone = phone;
//     _lname = lname;
//     _password = password;
//   }
//   BaseUser.create({
//     required String fname,
//     String? lname,
//     String? phone,
//     String? email,
//     String? password,
//   }) {
//     _email = email;
//     _fname = fname;
//     _phone = phone;
//     _lname = lname;
//     _password = password;
//   }

//   int? id;

//   late String _fname;
//   String? _lname;
//   String? _password;
//   String? _email;
//   String? _phone;

//   // Manager<BaseUser> objects = UserManager<BaseUser>();

//   set fname(String value) => _fname = value;
//   String get fname {
//     // modify something
//     return _fname;
//   }

//   set phone(String? value) => _phone = value;
//   String? get phone {
//     // modify something
//     return _phone;
//   }

//   set lname(String? value) => _lname = value;
//   String? get lname {
//     // modify something
//     return _lname;
//   }

//   set email(String? value) {
//     // modify
//     _email = normalizeEmail(value!);
//   }

//   String? get email {
//     // modify
//     return _email;
//   }

//   set password(String? value) {
//     // Hash the password
//     _password = hash256(password!);
//   }

//   String? get password {
//     // pass
//     return _password;
//   }

//   String? hash256(String value) => hash256(value);

//   String normalizeEmail(String value) {
//     return value;
//   }

//   Map<String, dynamic> toJson({
//     List<String>? only,
//     List<String>? exclude,
//   }) {
//     final data = {
//       'id': id,
//       'fname': fname,
//       'lname': lname,
//       'email': email,
//       'phone': phone,
//       'password': password,
//     };

//     if (only != null) {
//       for (final entry in data.entries) {
//         if (!only.contains(entry.key)) {
//           data.remove(entry.key);
//         }
//       }
//       return data;
//     }
//     if (exclude != null) {
//       for (final key in exclude) {
//         data.remove(key);
//       }
//       return data;
//     }

//     return data;
//   }

//   Future<void> save() async {}
// }

// // @JsonSerializable()
// class User {
//   User({
//     required this.firstName,
//     required this.lastName,
//     this.email,
//     this.phone,
//   });
//   String firstName;
//   String? lastName;
//   String? email;
//   String? phone;
//   int? id;
//   static String get table => UserExt.table;
//   static List<String> get columns => UserExt.columns;
//   static User fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
//   Map<String, dynamic> toJson() => _$UserToJson(this);

//   // Future<User?> create(Map<String, dynamic> json) async {
//   //   final conn = await Database().connection;

//   //   final query = Query.insert(table: 'user', columns: json);

//   //   final result = await conn.runTx((session) {
//   //     return session.execute(query.toString());
//   //   });

//   //   return result.isEmpty ? null : fromJson(result.first.toColumnMap());
//   // }

//   // Future<User> update(Map<String, dynamic> json) async {
//   //   if (id == null || json.isEmpty) return this;
//   //   final conn = await Database().connection;
//   //   final query = Query.update(
//   //     table: table,
//   //     columns: json,
//   //     operation: Operation('id', Operator.eq, '$id'),
//   //   );
//   //   final result = await conn.runTx((session) {
//   //     return session.execute(query.toString());
//   //   });

//   //   return User.fromJson(result.first.toColumnMap());
//   // }

//   // Future<int> delete() async {
//   //   final conn = await Database().connection;
//   //   if (id == null) return -1;

//   //   final query = Query.delete(
//   //     table: table,
//   //     operation: Operation('id', Operator.eq, '$id'),
//   //   );
//   //   final result = await conn.execute(query.toString());

//   //   return result.first.isEmpty ? -1 : id!;
//   // }

//   // static Future<Iterable<User>> filter([Operation? op]) async {
//   //   final conn = await Database().connection;

//   //   final query = Query.select(table: table, columns: columns, operation: op);

//   //   final result = await conn.execute(query.toString());

//   //   return result.map((element) => User.fromJson(element.toColumnMap()));
//   // }

//   static Future<int> get count async => UserExt.count();

//   // static Future<int> count([Operation? op]) async {
//   //   final conn = await Database().connection;

//   //   final query =
//   //       Query.select(table: table, columns: columns, operation: op).count();

//   //   final result = await conn.execute(query);

//   //   return result.first.toColumnMap()['count'] as int;
//   // }

//   // static Future<Iterable<User>> all() async {
//   //   final conn = await Database().connection;

//   //   final query = Query.select(table: table, columns: columns);

//   //   final result = await conn.execute(query.toString());

//   //   return result.map((element) => User.fromJson(element.toColumnMap()));
//   // }
// }
