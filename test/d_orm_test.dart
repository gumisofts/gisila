import 'package:pg_dorm/database/connections.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

import 'models/schema.dart';

void main() async {
  Database.init(endpoints: [
    Endpoint(host: 'host', database: 'database'),
  ], poolSetting: PoolSettings());

  final user = await UserDb.create(name: 'name');

  expect(user.name, 'name');
}
