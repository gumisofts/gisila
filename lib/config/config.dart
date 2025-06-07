/// Gisila Database Configuration Module
/// 
/// This module provides comprehensive database configuration management
/// with support for multiple database connections, connection pooling,
/// and environment-based configuration.
/// 
/// ## Features:
/// 
/// - **Multiple Database Support**: PostgreSQL, MySQL, SQLite
/// - **Connection Pooling**: Efficient connection reuse with automatic cleanup
/// - **Environment Configuration**: Load from environment variables or YAML files
/// - **Connection String Parsing**: Support for standard database URLs
/// - **Health Monitoring**: Connection health checks and automatic recovery
/// - **Statistics Tracking**: Pool usage statistics and monitoring
/// 
/// ## Basic Usage:
/// 
/// ```dart
/// import 'package:gisila/config/config.dart';
/// 
/// // Load from YAML file
/// final config = await DatabaseConfig.fromFile('database.yaml');
/// 
/// // Get default connection
/// final connection = config.defaultConnection;
/// 
/// // Use with connection pooling
/// final poolManager = PoolManager(
///   factory: YourConnectionFactory(),
///   config: config,
/// );
/// await poolManager.initialize();
/// 
/// final pooledConnection = await poolManager.getConnection();
/// // Use connection...
/// await poolManager.releaseConnection(pooledConnection);
/// ```
/// 
/// ## Environment Configuration:
/// 
/// ```dart
/// // Load from environment variables
/// final config = await DatabaseConfig.fromEnvironment();
/// 
/// // Environment variables:
/// // DATABASE_URL=postgresql://user:pass@localhost:5432/myapp
/// // DB_CONNECTIONS=cache,analytics
/// // DB_CACHE_URL=sqlite:///tmp/cache.db
/// // DB_ANALYTICS_URL=postgresql://analytics:secret@host:5432/warehouse
/// ```
library gisila.config;

export 'database_config.dart';
export 'connection_pool.dart'; 