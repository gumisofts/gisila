import 'dart:async';

import 'package:postgres/postgres.dart';
import 'package:project_mega/database/extensions.dart';
import 'package:project_mega/models/models.dart';
import 'package:project_mega/models/test/schema.dart';

void main() async {
  // final user = User(firstName: 'Alamudin');
  // final userInser = await User.create(user);
  final shop = Shop(
    name: 'Kooler Shop',
    owner: User(firstName: 'firstName'),
    address: Address(),
  );

  // print(userInser!.id);

// User.filter(where: where)
  final users = await User.filter(where: (t) => null);

  for (var us in users) {
    print('${us.firstName}  ${us.id}');
  }
  // User.filter(where: (t) => t.lastName.equals('other'));

  // print('Hello'.safe);
}

Future<void> filter(Operation Function(UserQuery t) where) async {
  final tt = where(UserQuery());

  print(tt.joins);
  final ll = Query.select(
    table: UserQuery.table,
    columns: UserQuery.columns,
    operation: tt,
    joins: tt.joins,
  );
  final conn = await Database().connection;

  print(ll);
  final result = await conn.execute(ll.toString());

  print(result);

  await conn.close();
}

// fullSerch() async {
//   const full =
//       "SELECT 'a fat cat sat on a mat and ate a fat rat'::tsvector @@ 'cat & rat'::tsquery;";
//   final conn = await Database().connection;

//   final result = await conn.execute(full);
//   print(result);
// }
