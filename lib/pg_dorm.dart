import 'package:pg_dorm/database/postgres/core/database.dart';
import 'package:postgres/postgres.dart';
export 'package:postgres/postgres.dart';
export 'package:pg_dorm/database/postgres/core/connections.dart';
export 'package:pg_dorm/database/postgres/core/database.dart';
export 'package:pg_dorm/database/postgres/exceptions.dart';
export 'package:pg_dorm/database/extensions.dart';
export 'package:pg_dorm/database/postgres/query/operator.dart';
export 'package:pg_dorm/database/postgres/query/query.dart';

void main(List<String> args) async {
  final sql = '''SELECT
    name as auth_permission_name
from
    "auth_permission"''';

  Database.init(endpoints: [
    Endpoint(
        host: 'localhost',
        database: 'bita-dev',
        username: 'postgres',
        password: 'mnbvcxz')
  ], poolSetting: PoolSettings(sslMode: SslMode.disable));
  final res = await Database.execute(sql);

  print(res.first);

  print(res.map((element) => element.toColumnMap()).first);
}
