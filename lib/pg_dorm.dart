import 'package:pg_dorm/database/postgres/core/database.dart';
export 'package:postgres/postgres.dart';
export 'package:pg_dorm/database/postgres/core/connections.dart';
export 'package:pg_dorm/database/postgres/core/database.dart';
export 'package:pg_dorm/database/postgres/exceptions.dart';
export 'package:pg_dorm/database/extensions.dart';
export 'package:pg_dorm/database/postgres/query/operator.dart';
export 'package:pg_dorm/database/postgres/query/query.dart';

void main(List<String> args) async {
  final sql = '''SELECT
    "user".*,
    "password".*
from
    "password"
    right Join "user" on "password"."userId" = "user"."userId";''';
  final res = await Database.execute(sql);

  print(res.map((element) => element.toColumnMap()).first);
}
