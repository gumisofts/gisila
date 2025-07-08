import 'package:gisila/database/postgres/core/database.dart';
import 'package:postgres/postgres.dart';
export 'package:postgres/postgres.dart';
export 'package:gisila/database/postgres/core/connections.dart';
export 'package:gisila/database/postgres/core/database.dart';
export 'package:gisila/database/postgres/exceptions.dart';
export 'package:gisila/database/extensions.dart';
export 'package:gisila/database/postgres/query/operator.dart';
export 'package:gisila/database/postgres/query/query.dart';
export 'package:gisila/database/postgres/query/select.dart';
export 'package:gisila/database/types.dart';
export 'package:gisila/database/postgres/definitions/table_definition.dart'
    hide IndexDefinition;
export 'package:gisila/database/postgres/definitions/column_definitions.dart';
export 'package:gisila/database/postgres/data_types/mappings.dart';
export 'package:gisila/config/config.dart';
export 'package:gisila/migrations/migration_manager.dart';
export 'package:gisila/migrations/schema_differ.dart';
export 'package:gisila/generators/schema_parser.dart';
export 'package:gisila/generators/code_generator.dart';

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
