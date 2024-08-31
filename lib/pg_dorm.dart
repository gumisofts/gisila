import 'package:pg_dorm/database/database.dart';
export 'package:postgres/postgres.dart';
export 'package:pg_dorm/database/connections.dart';
export 'package:pg_dorm/database/database.dart';
export 'package:pg_dorm/database/exceptions.dart';
export 'package:pg_dorm/database/extensions.dart';
export 'package:pg_dorm/database/operator.dart';
export 'package:pg_dorm/database/query.dart';
export 'package:pg_dorm/database/models.dart';

void main(List<String> args) async {
  // final user = await UserDb.create(firstName: 'Murad', lastName: "Hussen");
  // final shop =
  //     await ShopDb.create(name: "Electronics", ownerId: '0', addressId: '0');
  // user.toJson();
  // Query.update(table: table, columns: columns, operation: operation)

  // final user = await UserDb.get(where: (t) => t.id.equals(3));

  // user.save();

  // UserDb.filter(where: (t) => null);

  // ShopDb.filter(where: (t) => null);

  // print(user);
  final sql = '''SELECT
    "user".*,
    "password".*
from
    "password"
    right Join "user" on "password"."userId" = "user"."userId";''';
  final res = await Database.execute(sql);

  print(res.map((element) => element.toColumnMap()).first);
}
