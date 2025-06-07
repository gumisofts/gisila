/// Example usage of Gisila Database Configuration System
/// 
/// This file demonstrates various ways to configure and use
/// multiple database connections in your Gisila ORM application.

import 'dart:async';
import 'dart:io';

import '../lib/config/database_config.dart';
import '../lib/config/connection_pool.dart';

// Example connection factory for PostgreSQL
class PostgresConnectionFactory implements ConnectionFactory<MockPostgresConnection> {
  @override
  Future<MockPostgresConnection> createConnection(DatabaseConnection config) async {
    // In real implementation, this would create actual database connection
    print('Creating PostgreSQL connection to ${config.host}:${config.port}/${config.database}');
    await Future.delayed(Duration(milliseconds: 100)); // Simulate connection time
    return MockPostgresConnection(config);
  }

  @override
  Future<void> closeConnection(MockPostgresConnection connection) async {
    print('Closing connection ${connection.id}');
    connection.close();
  }

  @override
  Future<bool> isConnectionHealthy(MockPostgresConnection connection) async {
    return connection.isHealthy;
  }

  @override
  Future<void> resetConnection(MockPostgresConnection connection) async {
    print('Resetting connection ${connection.id}');
    connection.reset();
  }
}

// Mock connection class for example purposes
class MockPostgresConnection {
  final String id;
  final DatabaseConnection config;
  bool isHealthy = true;
  bool isClosed = false;

  MockPostgresConnection(this.config) : id = 'mock_${DateTime.now().millisecondsSinceEpoch}';

  void close() {
    isClosed = true;
    isHealthy = false;
  }

  void reset() {
    // Reset connection state
  }
}

/// Example 1: Basic configuration from YAML file
Future<void> exampleBasicConfiguration() async {
  print('\n=== Example 1: Basic Configuration ===');
  
  try {
    // Load configuration from YAML file
    final config = await DatabaseConfig.fromFile('example/database.yaml');
    
    print('Default connection: ${config.defaultConnection.name}');
    print('Available connections: ${config.connectionNames}');
    
    // Get specific connections
    final mainDb = config.getConnection('postgres_main');
    final readReplica = config.getConnection('postgres_read');
    
    print('Main DB: ${mainDb?.connectionString}');
    print('Read Replica: ${readReplica?.connectionString}');
    
  } catch (e) {
    print('Error loading configuration: $e');
  }
}

/// Example 2: Programmatic configuration
Future<void> exampleProgrammaticConfiguration() async {
  print('\n=== Example 2: Programmatic Configuration ===');
  
  final config = DatabaseConfig();
  
  // Add PostgreSQL connection
  config.addConnection(DatabaseConnection.postgresql(
    name: 'primary',
    host: 'localhost',
    database: 'myapp',
    username: 'user',
    password: 'password',
    port: 5432,
    maxConnections: 15,
    minConnections: 3,
  ));
  
  // Add SQLite connection
  config.addConnection(DatabaseConnection.sqlite(
    name: 'cache',
    database: 'cache.db',
    maxConnections: 1,
  ));
  
  // Add MySQL connection
  config.addConnection(DatabaseConnection.mysql(
    name: 'legacy',
    host: 'legacy.mysql.com',
    database: 'legacy_db',
    username: 'legacy_user',
    password: 'legacy_pass',
    useSSL: true,
  ));
  
  config.setDefaultConnection('primary');
  
  print('Configuration created with ${config.connectionNames.length} connections');
  print('Connections: ${config.connectionNames}');
  
  // Export to YAML
  print('\nGenerated YAML configuration:');
  print(config.toYamlString());
}

/// Example 3: Environment-based configuration
Future<void> exampleEnvironmentConfiguration() async {
  print('\n=== Example 3: Environment Configuration ===');
  
  // Simulate environment variables
  final envVars = {
    'DATABASE_URL': 'postgresql://user:pass@localhost:5432/myapp',
    'DB_CONNECTIONS': 'cache,analytics',
    'DB_CACHE_URL': 'sqlite:///tmp/cache.db',
    'DB_ANALYTICS_URL': 'postgresql://analytics:secret@analytics.internal:5432/warehouse',
  };
  
  final config = await DatabaseConfig.fromEnvironment(
    configFile: 'nonexistent.yaml', // File doesn't exist, will use env vars
    envOverrides: envVars,
  );
  
  print('Loaded from environment:');
  print('Default connection: ${config.defaultConnection.name}');
  print('Available connections: ${config.connectionNames}');
  
  for (final name in config.connectionNames) {
    final conn = config.getConnection(name);
    print('$name: ${conn?.connectionString}');
  }
}

/// Example 4: Connection pooling
Future<void> exampleConnectionPooling() async {
  print('\n=== Example 4: Connection Pooling ===');
  
  // Create configuration
  final dbConfig = DatabaseConnection.postgresql(
    name: 'pooled',
    host: 'localhost',
    database: 'test',
    username: 'user',
    password: 'password',
    maxConnections: 5,
    minConnections: 2,
  );
  
  // Create connection pool
  final factory = PostgresConnectionFactory();
  final pool = ConnectionPool<MockPostgresConnection>(
    config: dbConfig,
    factory: factory,
    maxIdleTime: Duration(minutes: 10),
    maxUsageCount: 100,
  );
  
  // Initialize pool
  await pool.initialize();
  print('Pool initialized with ${pool.getStatistics()['total_connections']} connections');
  
  // Use connections
  final connections = <PooledConnection<MockPostgresConnection>>[];
  
  // Get multiple connections
  for (int i = 0; i < 3; i++) {
    final connection = await pool.getConnection();
    connections.add(connection);
    print('Got connection ${connection.id} (usage: ${connection.usageCount})');
  }
  
  print('Pool stats: ${pool.getStatistics()}');
  
  // Release connections
  for (final connection in connections) {
    await pool.releaseConnection(connection);
    print('Released connection ${connection.id}');
  }
  
  print('Final pool stats: ${pool.getStatistics()}');
  
  // Close pool
  await pool.close();
  print('Pool closed');
}

/// Example 5: Multiple pool management
Future<void> exampleMultiplePoolManagement() async {
  print('\n=== Example 5: Multiple Pool Management ===');
  
  // Create configuration with multiple databases
  final config = DatabaseConfig(connections: [
    DatabaseConnection.postgresql(
      name: 'primary',
      host: 'localhost',
      database: 'primary',
      username: 'user',
      password: 'password',
      maxConnections: 10,
      minConnections: 2,
    ),
    DatabaseConnection.postgresql(
      name: 'analytics',
      host: 'analytics.internal',
      database: 'warehouse',
      username: 'analyst',
      password: 'secret',
      maxConnections: 5,
      minConnections: 1,
    ),
    DatabaseConnection.sqlite(
      name: 'cache',
      database: 'cache.db',
      maxConnections: 1,
      minConnections: 1,
    ),
  ]);
  
  // Create pool manager
  final factory = PostgresConnectionFactory();
  final poolManager = PoolManager<MockPostgresConnection>(
    factory: factory,
    config: config,
  );
  
  // Initialize all pools
  await poolManager.initialize();
  print('Initialized pools: ${poolManager.poolNames}');
  
  // Get connections from different pools
  final primaryConn = await poolManager.getConnection('primary');
  final analyticsConn = await poolManager.getConnection('analytics');
  final cacheConn = await poolManager.getConnection('cache');
  
  print('Primary connection: ${primaryConn.id}');
  print('Analytics connection: ${analyticsConn.id}');
  print('Cache connection: ${cacheConn.id}');
  
  // Show all pool statistics
  final allStats = poolManager.getAllStatistics();
  for (final entry in allStats.entries) {
    print('Pool ${entry.key}: ${entry.value}');
  }
  
  // Release connections
  await poolManager.releaseConnection(primaryConn);
  await poolManager.releaseConnection(analyticsConn);
  await poolManager.releaseConnection(cacheConn);
  
  print('Pool manager health: ${poolManager.isHealthy}');
  
  // Close all pools
  await poolManager.close();
  print('All pools closed');
}

/// Example 6: Configuration validation and error handling
Future<void> exampleConfigurationValidation() async {
  print('\n=== Example 6: Configuration Validation ===');
  
  try {
    // Create invalid configuration
    final config = DatabaseConfig();
    
    // Try to get non-existent connection
    try {
      final connection = config.getConnection('nonexistent');
      print('This should not print: $connection');
    } catch (e) {
      print('Expected error for nonexistent connection: $e');
    }
    
    // Try to access default connection when none exists
    try {
      final defaultConn = config.defaultConnection;
      print('This should not print: $defaultConn');
    } catch (e) {
      print('Expected error for missing default connection: $e');
    }
    
    // Add a connection and set it as default
    config.addConnection(DatabaseConnection.sqlite(
      name: 'test',
      database: 'test.db',
    ));
    config.setDefaultConnection('test');
    
    // Now it should work
    final connection = config.defaultConnection;
    print('Successfully got default connection: ${connection.name}');
    
    // Try to remove the default connection
    try {
      config.removeConnection('test');
      print('This should not print');
    } catch (e) {
      print('Expected error when removing default connection: $e');
    }
    
  } catch (e) {
    print('Unexpected error: $e');
  }
}

/// Example 7: Saving and loading configuration
Future<void> exampleSaveLoadConfiguration() async {
  print('\n=== Example 7: Save/Load Configuration ===');
  
  // Create configuration
  final config = DatabaseConfig(connections: [
    DatabaseConnection.postgresql(
      name: 'production',
      host: 'prod.example.com',
      database: 'myapp_prod',
      username: 'prod_user',
      password: 'prod_password',
      useSSL: true,
      maxConnections: 20,
      minConnections: 5,
    ),
    DatabaseConnection.sqlite(
      name: 'development',
      database: 'dev.db',
    ),
  ], defaultConnection: 'production');
  
  // Save configuration to file
  const configFile = 'example/generated_config.yaml';
  await config.saveToFile(configFile);
  print('Configuration saved to $configFile');
  
  // Load configuration back
  final loadedConfig = await DatabaseConfig.fromFile(configFile);
  print('Configuration loaded from file');
  print('Default connection: ${loadedConfig.defaultConnection.name}');
  print('Available connections: ${loadedConfig.connectionNames}');
  
  // Compare original and loaded
  final originalYaml = config.toYamlString();
  final loadedYaml = loadedConfig.toYamlString();
  print('Configurations match: ${originalYaml == loadedYaml}');
  
  // Clean up
  try {
    await File(configFile).delete();
    print('Temporary config file deleted');
  } catch (e) {
    print('Could not delete temporary file: $e');
  }
}

/// Main function to run all examples
Future<void> main() async {
  print('Gisila Database Configuration Examples');
  print('======================================');
  
  await exampleBasicConfiguration();
  await exampleProgrammaticConfiguration();
  await exampleEnvironmentConfiguration();
  await exampleConnectionPooling();
  await exampleMultiplePoolManagement();
  await exampleConfigurationValidation();
  await exampleSaveLoadConfiguration();
  
  print('\n=== All Examples Completed ===');
} 