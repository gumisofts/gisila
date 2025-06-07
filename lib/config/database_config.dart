/// Database configuration handler for Gisila ORM
///
/// Supports multiple database connections with environment-based configuration
/// and connection pooling capabilities.
library gisila.config;

import 'dart:io';
import 'package:yaml/yaml.dart';
import 'connection_pool.dart';

/// Supported database types
enum DatabaseType {
  postgresql,
  sqlite,
  mysql,
}

/// Database connection configuration
class DatabaseConnection {
  /// Connection identifier
  final String name;

  /// Database type
  final DatabaseType type;

  /// Database host (not used for SQLite)
  final String? host;

  /// Database port (not used for SQLite)
  final int? port;

  /// Database name or file path for SQLite
  final String database;

  /// Username (not used for SQLite)
  final String? username;

  /// Password (not used for SQLite)
  final String? password;

  /// SSL mode for PostgreSQL
  final bool useSSL;

  /// Connection timeout in seconds
  final int connectionTimeout;

  /// Query timeout in seconds
  final int queryTimeout;

  /// Maximum number of connections in pool
  final int maxConnections;

  /// Minimum number of connections in pool
  final int minConnections;

  /// Additional connection parameters
  final Map<String, dynamic> additionalParams;

  const DatabaseConnection({
    required this.name,
    required this.type,
    required this.database,
    this.host,
    this.port,
    this.username,
    this.password,
    this.useSSL = false,
    this.connectionTimeout = 30,
    this.queryTimeout = 30,
    this.maxConnections = 10,
    this.minConnections = 2,
    this.additionalParams = const {},
  });

  /// Create PostgreSQL connection configuration
  factory DatabaseConnection.postgresql({
    required String name,
    required String host,
    required String database,
    required String username,
    required String password,
    int port = 5432,
    bool useSSL = false,
    int connectionTimeout = 30,
    int queryTimeout = 30,
    int maxConnections = 10,
    int minConnections = 2,
    Map<String, dynamic> additionalParams = const {},
  }) {
    return DatabaseConnection(
      name: name,
      type: DatabaseType.postgresql,
      host: host,
      port: port,
      database: database,
      username: username,
      password: password,
      useSSL: useSSL,
      connectionTimeout: connectionTimeout,
      queryTimeout: queryTimeout,
      maxConnections: maxConnections,
      minConnections: minConnections,
      additionalParams: additionalParams,
    );
  }

  /// Create SQLite connection configuration
  factory DatabaseConnection.sqlite({
    required String name,
    required String database,
    int connectionTimeout = 30,
    int queryTimeout = 30,
    int maxConnections = 1,
    int minConnections = 1,
    Map<String, dynamic> additionalParams = const {},
  }) {
    return DatabaseConnection(
      name: name,
      type: DatabaseType.sqlite,
      database: database,
      connectionTimeout: connectionTimeout,
      queryTimeout: queryTimeout,
      maxConnections: maxConnections,
      minConnections: minConnections,
      additionalParams: additionalParams,
    );
  }

  /// Create MySQL connection configuration
  factory DatabaseConnection.mysql({
    required String name,
    required String host,
    required String database,
    required String username,
    required String password,
    int port = 3306,
    bool useSSL = false,
    int connectionTimeout = 30,
    int queryTimeout = 30,
    int maxConnections = 10,
    int minConnections = 2,
    Map<String, dynamic> additionalParams = const {},
  }) {
    return DatabaseConnection(
      name: name,
      type: DatabaseType.mysql,
      host: host,
      port: port,
      database: database,
      username: username,
      password: password,
      useSSL: useSSL,
      connectionTimeout: connectionTimeout,
      queryTimeout: queryTimeout,
      maxConnections: maxConnections,
      minConnections: minConnections,
      additionalParams: additionalParams,
    );
  }

  /// Create connection configuration from map
  factory DatabaseConnection.fromMap(String name, Map<String, dynamic> config) {
    final typeStr = config['type'] as String;
    final type = DatabaseType.values.firstWhere(
      (e) => e.toString().split('.').last == typeStr,
      orElse: () => throw ArgumentError('Unsupported database type: $typeStr'),
    );

    return DatabaseConnection(
      name: name,
      type: type,
      host: config['host'] as String?,
      port: config['port'] as int?,
      database: config['database'] as String,
      username: config['username'] as String?,
      password: config['password'] as String?,
      useSSL: config['ssl'] as bool? ?? false,
      connectionTimeout: config['connection_timeout'] as int? ?? 30,
      queryTimeout: config['query_timeout'] as int? ?? 30,
      maxConnections: config['max_connections'] as int? ?? 10,
      minConnections: config['min_connections'] as int? ?? 2,
      additionalParams:
          config['additional_params'] as Map<String, dynamic>? ?? {},
    );
  }

  /// Convert to map for serialization
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'type': type.toString().split('.').last,
      'database': database,
      'connection_timeout': connectionTimeout,
      'query_timeout': queryTimeout,
      'max_connections': maxConnections,
      'min_connections': minConnections,
    };

    if (host != null) map['host'] = host;
    if (port != null) map['port'] = port;
    if (username != null) map['username'] = username;
    if (password != null) map['password'] = password;
    if (useSSL) map['ssl'] = useSSL;
    if (additionalParams.isNotEmpty)
      map['additional_params'] = additionalParams;

    return map;
  }

  /// Generate connection string for the database
  String get connectionString {
    switch (type) {
      case DatabaseType.postgresql:
        final ssl = useSSL ? '?sslmode=require' : '';
        return 'postgresql://$username:$password@$host:$port/$database$ssl';

      case DatabaseType.mysql:
        final ssl = useSSL ? '?useSSL=true' : '';
        return 'mysql://$username:$password@$host:$port/$database$ssl';

      case DatabaseType.sqlite:
        return 'sqlite:///$database';
    }
  }

  @override
  String toString() {
    return 'DatabaseConnection(name: $name, type: $type, database: $database)';
  }
}

/// Main database configuration manager
class DatabaseConfig {
  /// Map of database connections by name
  final Map<String, DatabaseConnection> _connections = {};

  /// Default connection name
  String _defaultConnection = 'default';

  /// Create database configuration
  DatabaseConfig({
    List<DatabaseConnection> connections = const [],
    String defaultConnection = 'default',
  }) : _defaultConnection = defaultConnection {
    for (final connection in connections) {
      _connections[connection.name] = connection;
    }
  }

  /// Load configuration from YAML file
  static Future<DatabaseConfig> fromFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('Database config file not found: $filePath');
    }

    final content = await file.readAsString();
    final yaml = loadYaml(content) as Map;

    return DatabaseConfig.fromMap(yaml);
  }

  /// Create configuration from map
  static DatabaseConfig fromMap(Map<dynamic, dynamic> config) {
    final connections = <DatabaseConnection>[];
    final connectionsMap =
        config['connections'] as Map<dynamic, dynamic>? ?? {};

    for (final entry in connectionsMap.entries) {
      final name = entry.key as String;
      final connectionConfig = entry.value as Map<dynamic, dynamic>;
      connections.add(DatabaseConnection.fromMap(
          name, connectionConfig.cast<String, dynamic>()));
    }

    final defaultConnection = config['default'] as String? ?? 'default';

    return DatabaseConfig(
      connections: connections,
      defaultConnection: defaultConnection,
    );
  }

  /// Load configuration with environment variable support
  static Future<DatabaseConfig> fromEnvironment({
    String configFile = 'database.yaml',
    Map<String, String>? envOverrides,
  }) async {
    final env = envOverrides ?? Platform.environment;

    // Try to load from file first
    DatabaseConfig config;
    final file = File(configFile);

    if (await file.exists()) {
      config = await DatabaseConfig.fromFile(configFile);
    } else {
      config = DatabaseConfig();
    }

    // Override with environment variables
    config._loadFromEnvironment(env);

    return config;
  }

  /// Load configuration from environment variables
  void _loadFromEnvironment(Map<String, String> env) {
    // Load default connection from environment
    final dbUrl = env['DATABASE_URL'];
    if (dbUrl != null) {
      final connection = _parseConnectionString('default', dbUrl);
      _connections['default'] = connection;
    }

    // Load additional connections
    final connectionNames = env['DB_CONNECTIONS']?.split(',') ?? [];
    for (final name in connectionNames) {
      final prefix = 'DB_${name.toUpperCase()}';
      final url = env['${prefix}_URL'];

      if (url != null) {
        final connection = _parseConnectionString(name.trim(), url);
        _connections[name.trim()] = connection;
      }
    }
  }

  /// Parse connection string into DatabaseConnection
  DatabaseConnection _parseConnectionString(
      String name, String connectionString) {
    final uri = Uri.parse(connectionString);

    DatabaseType type;
    switch (uri.scheme) {
      case 'postgresql':
      case 'postgres':
        type = DatabaseType.postgresql;
        break;
      case 'mysql':
        type = DatabaseType.mysql;
        break;
      case 'sqlite':
        type = DatabaseType.sqlite;
        break;
      default:
        throw ArgumentError('Unsupported database scheme: ${uri.scheme}');
    }

    if (type == DatabaseType.sqlite) {
      return DatabaseConnection.sqlite(
        name: name,
        database: uri.path,
      );
    }

    return DatabaseConnection(
      name: name,
      type: type,
      host: uri.host,
      port: uri.port,
      database: uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '',
      username: uri.userInfo.isNotEmpty ? uri.userInfo.split(':').first : null,
      password:
          uri.userInfo.contains(':') ? uri.userInfo.split(':').last : null,
      useSSL: uri.queryParameters.containsKey('sslmode') ||
          uri.queryParameters.containsKey('useSSL'),
    );
  }

  /// Add a database connection
  void addConnection(DatabaseConnection connection) {
    _connections[connection.name] = connection;
  }

  /// Remove a database connection
  void removeConnection(String name) {
    if (name == _defaultConnection) {
      throw ArgumentError('Cannot remove the default connection');
    }
    _connections.remove(name);
  }

  /// Get a database connection by name
  DatabaseConnection? getConnection([String? name]) {
    final connectionName = name ?? _defaultConnection;
    return _connections[connectionName];
  }

  /// Get the default database connection
  DatabaseConnection get defaultConnection {
    final connection = _connections[_defaultConnection];
    if (connection == null) {
      throw StateError('Default connection "$_defaultConnection" not found');
    }
    return connection;
  }

  /// Set the default connection
  void setDefaultConnection(String name) {
    if (!_connections.containsKey(name)) {
      throw ArgumentError('Connection "$name" does not exist');
    }
    _defaultConnection = name;
  }

  /// Get all connection names
  List<String> get connectionNames => _connections.keys.toList();

  /// Check if a connection exists
  bool hasConnection(String name) => _connections.containsKey(name);

  /// Get all connections
  Map<String, DatabaseConnection> get connections =>
      Map.unmodifiable(_connections);

  /// Export configuration to map
  Map<String, dynamic> toMap() {
    return {
      'default': _defaultConnection,
      'connections': _connections
          .map((name, connection) => MapEntry(name, connection.toMap())),
    };
  }

  /// Export configuration to YAML string
  String toYamlString() {
    final buffer = StringBuffer();
    buffer.writeln('# Gisila Database Configuration');
    buffer.writeln('default: $_defaultConnection');
    buffer.writeln();
    buffer.writeln('connections:');

    for (final entry in _connections.entries) {
      final name = entry.key;
      final connection = entry.value;

      buffer.writeln('  $name:');
      buffer.writeln('    type: ${connection.type.toString().split('.').last}');

      if (connection.host != null) {
        buffer.writeln('    host: ${connection.host}');
      }
      if (connection.port != null) {
        buffer.writeln('    port: ${connection.port}');
      }

      buffer.writeln('    database: ${connection.database}');

      if (connection.username != null) {
        buffer.writeln('    username: ${connection.username}');
      }
      if (connection.password != null) {
        buffer.writeln('    password: ${connection.password}');
      }

      if (connection.useSSL) {
        buffer.writeln('    ssl: true');
      }

      buffer.writeln('    connection_timeout: ${connection.connectionTimeout}');
      buffer.writeln('    query_timeout: ${connection.queryTimeout}');
      buffer.writeln('    max_connections: ${connection.maxConnections}');
      buffer.writeln('    min_connections: ${connection.minConnections}');

      if (connection.additionalParams.isNotEmpty) {
        buffer.writeln('    additional_params:');
        for (final param in connection.additionalParams.entries) {
          buffer.writeln('      ${param.key}: ${param.value}');
        }
      }

      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Save configuration to file
  Future<void> saveToFile(String filePath) async {
    final file = File(filePath);
    await file.writeAsString(toYamlString());
  }

  /// Get connection pool for a specific connection
  /// This method creates a new pool each time it's called
  /// For production use, consider implementing a pool manager
  Future<ConnectionPool<dynamic>> getConnectionPool(
      [String? connectionName]) async {
    final connection = getConnection(connectionName);
    if (connection == null) {
      final name = connectionName ?? _defaultConnection;
      throw StateError('Connection "$name" not found');
    }

    // Create a simple connection factory for this connection
    final factory = SimpleConnectionFactory();

    final pool = ConnectionPool<dynamic>(
      config: connection,
      factory: factory,
    );

    await pool.initialize();
    return pool;
  }
}

/// Simple connection factory implementation
/// This is a basic implementation for the migration system
class SimpleConnectionFactory implements ConnectionFactory<dynamic> {
  @override
  Future<dynamic> createConnection(DatabaseConnection config) async {
    // This is a placeholder implementation
    // In a real implementation, this would create actual database connections
    // using the appropriate database driver (postgresql, mysql, sqlite)
    return SimpleConnection(config);
  }

  @override
  Future<void> closeConnection(dynamic connection) async {
    if (connection is SimpleConnection) {
      await connection.close();
    }
  }

  @override
  Future<bool> isConnectionHealthy(dynamic connection) async {
    if (connection is SimpleConnection) {
      return connection.isHealthy;
    }
    return false;
  }

  @override
  Future<void> resetConnection(dynamic connection) async {
    if (connection is SimpleConnection) {
      await connection.reset();
    }
  }
}

/// Simple connection implementation for migration system
class SimpleConnection {
  final DatabaseConnection config;
  bool _closed = false;

  SimpleConnection(this.config);

  bool get isHealthy => !_closed;

  Future<List<Map<String, dynamic>>> query(String sql,
      [List<dynamic>? parameters]) async {
    if (_closed) throw StateError('Connection is closed');

    // This is a placeholder implementation
    // In a real implementation, this would execute the SQL query
    // against the actual database using the appropriate driver

    // For migration tracking table queries, return empty results
    if (sql.contains('gisila_migrations')) {
      return [];
    }

    throw UnimplementedError(
        'SimpleConnection.query() needs database driver implementation');
  }

  Future<void> execute(String sql, [List<dynamic>? parameters]) async {
    if (_closed) throw StateError('Connection is closed');

    // This is a placeholder implementation
    // In a real implementation, this would execute the SQL statement
    // against the actual database using the appropriate driver

    print('Executing SQL: $sql');
    if (parameters != null && parameters.isNotEmpty) {
      print('Parameters: $parameters');
    }
  }

  Future<T> transaction<T>(Future<T> Function() action) async {
    if (_closed) throw StateError('Connection is closed');

    // This is a placeholder implementation
    // In a real implementation, this would handle database transactions

    print('Starting transaction');
    try {
      final result = await action();
      print('Committing transaction');
      return result;
    } catch (e) {
      print('Rolling back transaction: $e');
      rethrow;
    }
  }

  Future<void> close() async {
    _closed = true;
    print('Connection closed');
  }

  Future<void> reset() async {
    if (_closed) throw StateError('Connection is closed');

    // This is a placeholder implementation
    // In a real implementation, this would reset the connection state
    print('Connection reset');
  }
}
