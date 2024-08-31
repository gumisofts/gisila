import 'package:pg_dorm/database/query.dart';
import 'package:postgres/postgres.dart';

// Database for
class Database {
  factory Database() => _instance;
  Database._init();
  static final Database _instance = Database._init();
  static Pool<Connection>? _pool;
  static List<Endpoint>? _endpoints;
  static PoolSettings? _poolSetting;
  static bool _inilized = false;
  static void Function(dynamic)? _logger;
  factory Database.init({
    required List<Endpoint> endpoints,
    required PoolSettings? poolSetting,
    logger,
  }) {
    _endpoints = endpoints;
    _poolSetting = poolSetting;
    if (_inilized) {
      throw StateError('database already initilized!!');
    }
    _inilized = true;
    _logger = logger;
    return _instance;
  }
// Get pool  of the pg connection
  static Future<Result> execute(Object sql, {Object? parameters}) async {
    if (sql is Query) {
      return (await Database().pool).execute(sql.toString(),
          parameters: parameters, queryMode: QueryMode.extended);
    }
    // Explain Query
    if (sql is! Sql) {
      final explained = await (await Database().pool).execute('Explain $sql',
          parameters: parameters, queryMode: QueryMode.extended);
      if (_logger != null) _logger!(explained);
    }
    return (await Database().pool)
        .execute(sql, parameters: parameters, queryMode: QueryMode.extended);
  }

  static checkConnection() {
    execute('SELECT 1');
  }

  Future<Pool<Connection>> get pool async {
    if (!_inilized) {
      throw StateError(
          'database is not initilized: did you forget to call Database.init');
    }
    return _pool ??=
        Pool<Connection>.withEndpoints(_endpoints!, settings: _poolSetting);
  }
}
