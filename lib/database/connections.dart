import 'package:postgres/postgres.dart';
import 'package:project_mega/models/test/schema.dart';

// Database for
class Database {
  factory Database() => _instance;
  Database._init();
  static final Database _instance = Database._init();
  static Connection? _connection;
  // static Map<String, dynamic> config = {'host': 'localhost', 'port': ''};
  static Pool<Connection>? _pool;
// Get pool  of the pg connection
  Future<Pool<Connection>> get pool async {
    return _pool ??= Pool<Connection>.withEndpoints(
      [
        Endpoint(
          host: 'localhost',
          database: 'one_punch_db',
          username: 'one_punch_man',
          password: 'OnePunchMan',
          port: 5454,
        ),
      ],
      settings: const PoolSettings(
        maxConnectionAge: Duration(milliseconds: 1000),
        maxConnectionCount: 90,
        sslMode: SslMode.disable,
      ),
    );
  }

  Future<Connection> get connection async {
    _connection ??= await Connection.open(
      Endpoint(
        host: 'localhost',
        database: 'one_punch_db',
        username: 'one_punch_man',
        password: 'OnePunchMan',
        port: 5454,
      ),
      settings: const ConnectionSettings(sslMode: SslMode.disable),
    );
    return _connection!;
  }
}
