/// Database connection pool manager for Gisila ORM
///
/// Provides efficient connection pooling with automatic cleanup,
/// connection reuse, and health monitoring.
library gisila.config.pool;

import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'database_config.dart';

/// Connection status enum
enum ConnectionStatus {
  idle,
  busy,
  closed,
  error,
}

/// Wrapper for database connections with metadata
class PooledConnection<T> {
  /// The actual database connection
  final T connection;

  /// Unique identifier for the connection
  final String id;

  /// Current status of the connection
  ConnectionStatus status;

  /// When the connection was created
  final DateTime createdAt;

  /// When the connection was last used
  DateTime lastUsedAt;

  /// Number of times this connection has been used
  int usageCount;

  /// Connection configuration
  final DatabaseConnection config;

  PooledConnection({
    required this.connection,
    required this.config,
  })  : id = _generateConnectionId(),
        status = ConnectionStatus.idle,
        createdAt = DateTime.now(),
        lastUsedAt = DateTime.now(),
        usageCount = 0;

  /// Generate a unique connection ID
  static String _generateConnectionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(10000);
    return 'conn_${timestamp}_$random';
  }

  /// Mark connection as busy
  void markBusy() {
    status = ConnectionStatus.busy;
    lastUsedAt = DateTime.now();
    usageCount++;
  }

  /// Mark connection as idle
  void markIdle() {
    status = ConnectionStatus.idle;
  }

  /// Mark connection as closed
  void markClosed() {
    status = ConnectionStatus.closed;
  }

  /// Mark connection as error
  void markError() {
    status = ConnectionStatus.error;
  }

  /// Check if connection is available for use
  bool get isAvailable => status == ConnectionStatus.idle;

  /// Check if connection should be recycled
  bool shouldRecycle(Duration maxIdleTime, int maxUsageCount) {
    final idleTime = DateTime.now().difference(lastUsedAt);
    return idleTime > maxIdleTime || usageCount > maxUsageCount;
  }

  @override
  String toString() {
    return 'PooledConnection(id: $id, status: $status, usageCount: $usageCount)';
  }
}

/// Connection factory interface
abstract class ConnectionFactory<T> {
  /// Create a new database connection
  Future<T> createConnection(DatabaseConnection config);

  /// Close a database connection
  Future<void> closeConnection(T connection);

  /// Test if a connection is healthy
  Future<bool> isConnectionHealthy(T connection);

  /// Reset a connection to clean state
  Future<void> resetConnection(T connection);
}

/// Database connection pool
class ConnectionPool<T> {
  /// Connection configuration
  final DatabaseConnection _config;

  /// Connection factory
  final ConnectionFactory<T> _factory;

  /// Pool of available connections
  final Queue<PooledConnection<T>> _availableConnections = Queue();

  /// Pool of busy connections
  final Set<PooledConnection<T>> _busyConnections = {};

  /// Pool of all connections (for tracking)
  final Set<PooledConnection<T>> _allConnections = {};

  /// Completer for connection requests waiting for available connections
  final Queue<Completer<PooledConnection<T>>> _waitingQueue = Queue();

  /// Timer for periodic cleanup
  Timer? _cleanupTimer;

  /// Pool statistics
  int _totalConnectionsCreated = 0;
  int _totalConnectionsDestroyed = 0;
  int _totalConnectionRequests = 0;

  /// Pool configuration
  final Duration _maxIdleTime;
  final int _maxUsageCount;
  final Duration _cleanupInterval;
  final Duration _connectionTimeout;

  ConnectionPool({
    required DatabaseConnection config,
    required ConnectionFactory<T> factory,
    Duration maxIdleTime = const Duration(minutes: 30),
    int maxUsageCount = 1000,
    Duration cleanupInterval = const Duration(minutes: 5),
    Duration connectionTimeout = const Duration(seconds: 30),
  })  : _config = config,
        _factory = factory,
        _maxIdleTime = maxIdleTime,
        _maxUsageCount = maxUsageCount,
        _cleanupInterval = cleanupInterval,
        _connectionTimeout = connectionTimeout {
    _startCleanupTimer();
  }

  /// Initialize the pool with minimum connections
  Future<void> initialize() async {
    for (int i = 0; i < _config.minConnections; i++) {
      await _createConnection();
    }
  }

  /// Get a connection from the pool
  Future<PooledConnection<T>> getConnection() async {
    _totalConnectionRequests++;

    // Try to get an available connection
    if (_availableConnections.isNotEmpty) {
      final connection = _availableConnections.removeFirst();

      // Check if connection is still healthy
      if (await _isConnectionHealthy(connection)) {
        connection.markBusy();
        _busyConnections.add(connection);
        return connection;
      } else {
        // Connection is unhealthy, remove it
        await _destroyConnection(connection);
      }
    }

    // Create new connection if under max limit
    if (_allConnections.length < _config.maxConnections) {
      final connection = await _createConnection();
      connection.markBusy();
      _busyConnections.add(connection);
      return connection;
    }

    // Wait for a connection to become available
    final completer = Completer<PooledConnection<T>>();
    _waitingQueue.add(completer);

    // Set timeout for waiting
    Timer(_connectionTimeout, () {
      if (!completer.isCompleted) {
        _waitingQueue.remove(completer);
        completer.completeError(
            TimeoutException('Connection timeout', _connectionTimeout));
      }
    });

    return completer.future;
  }

  /// Return a connection to the pool
  Future<void> releaseConnection(PooledConnection<T> connection) async {
    if (!_busyConnections.remove(connection)) {
      // Connection not found in busy set, might be already released
      return;
    }

    try {
      // Reset connection to clean state
      await _factory.resetConnection(connection.connection);

      connection.markIdle();

      // Check if there are waiting requests
      if (_waitingQueue.isNotEmpty) {
        final waiter = _waitingQueue.removeFirst();
        if (!waiter.isCompleted) {
          connection.markBusy();
          _busyConnections.add(connection);
          waiter.complete(connection);
          return;
        }
      }

      // Add back to available pool
      _availableConnections.add(connection);
    } catch (e) {
      // Error resetting connection, destroy it
      connection.markError();
      await _destroyConnection(connection);
    }
  }

  /// Force close a connection (e.g., on error)
  Future<void> closeConnection(PooledConnection<T> connection) async {
    _busyConnections.remove(connection);
    _availableConnections.remove(connection);
    await _destroyConnection(connection);
  }

  /// Create a new connection
  Future<PooledConnection<T>> _createConnection() async {
    final dbConnection = await _factory.createConnection(_config);
    final pooledConnection = PooledConnection<T>(
      connection: dbConnection,
      config: _config,
    );

    _allConnections.add(pooledConnection);
    _totalConnectionsCreated++;

    return pooledConnection;
  }

  /// Destroy a connection
  Future<void> _destroyConnection(PooledConnection<T> connection) async {
    try {
      await _factory.closeConnection(connection.connection);
    } catch (e) {
      // Ignore errors when closing connection
    }

    connection.markClosed();
    _allConnections.remove(connection);
    _totalConnectionsDestroyed++;
  }

  /// Check if a connection is healthy
  Future<bool> _isConnectionHealthy(PooledConnection<T> connection) async {
    try {
      return await _factory.isConnectionHealthy(connection.connection);
    } catch (e) {
      return false;
    }
  }

  /// Start the cleanup timer
  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(_cleanupInterval, (_) => _cleanup());
  }

  /// Periodic cleanup of idle and stale connections
  Future<void> _cleanup() async {
    final connectionsToRemove = <PooledConnection<T>>[];

    // Find connections that should be recycled
    for (final connection in _availableConnections) {
      if (connection.shouldRecycle(_maxIdleTime, _maxUsageCount)) {
        connectionsToRemove.add(connection);
      }
    }

    // Remove stale connections
    for (final connection in connectionsToRemove) {
      _availableConnections.remove(connection);
      await _destroyConnection(connection);
    }

    // Ensure we have minimum connections
    while (_allConnections.length < _config.minConnections) {
      final connection = await _createConnection();
      _availableConnections.add(connection);
    }
  }

  /// Get pool statistics
  Map<String, dynamic> getStatistics() {
    return {
      'total_connections': _allConnections.length,
      'available_connections': _availableConnections.length,
      'busy_connections': _busyConnections.length,
      'waiting_requests': _waitingQueue.length,
      'total_created': _totalConnectionsCreated,
      'total_destroyed': _totalConnectionsDestroyed,
      'total_requests': _totalConnectionRequests,
      'min_connections': _config.minConnections,
      'max_connections': _config.maxConnections,
    };
  }

  /// Close the entire pool
  Future<void> close() async {
    _cleanupTimer?.cancel();

    // Complete all waiting requests with error
    while (_waitingQueue.isNotEmpty) {
      final waiter = _waitingQueue.removeFirst();
      if (!waiter.isCompleted) {
        waiter.completeError(StateError('Connection pool closed'));
      }
    }

    // Close all connections
    final allConnections = List<PooledConnection<T>>.from(_allConnections);
    for (final connection in allConnections) {
      await _destroyConnection(connection);
    }

    _availableConnections.clear();
    _busyConnections.clear();
    _allConnections.clear();
  }

  /// Check if pool is healthy
  bool get isHealthy {
    return _allConnections.isNotEmpty &&
        _cleanupTimer != null &&
        _cleanupTimer!.isActive;
  }

  @override
  String toString() {
    final stats = getStatistics();
    return 'ConnectionPool(total: ${stats['total_connections']}, '
        'available: ${stats['available_connections']}, '
        'busy: ${stats['busy_connections']})';
  }
}

/// Pool manager for multiple database connections
class PoolManager<T> {
  /// Map of connection pools by connection name
  final Map<String, ConnectionPool<T>> _pools = {};

  /// Connection factory
  final ConnectionFactory<T> _factory;

  /// Database configuration
  final DatabaseConfig _config;

  PoolManager({
    required ConnectionFactory<T> factory,
    required DatabaseConfig config,
  })  : _factory = factory,
        _config = config;

  /// Initialize all connection pools
  Future<void> initialize() async {
    for (final connection in _config.connections.values) {
      final pool = ConnectionPool<T>(
        config: connection,
        factory: _factory,
      );
      await pool.initialize();
      _pools[connection.name] = pool;
    }
  }

  /// Get a connection from the specified pool
  Future<PooledConnection<T>> getConnection([String? connectionName]) async {
    final name = connectionName ?? _config.defaultConnection.name;
    final pool = _pools[name];

    if (pool == null) {
      throw ArgumentError('Connection pool "$name" not found');
    }

    return pool.getConnection();
  }

  /// Release a connection back to its pool
  Future<void> releaseConnection(PooledConnection<T> connection) async {
    final pool = _pools[connection.config.name];
    if (pool != null) {
      await pool.releaseConnection(connection);
    }
  }

  /// Close a specific connection
  Future<void> closeConnection(PooledConnection<T> connection) async {
    final pool = _pools[connection.config.name];
    if (pool != null) {
      await pool.closeConnection(connection);
    }
  }

  /// Get statistics for all pools
  Map<String, Map<String, dynamic>> getAllStatistics() {
    return _pools.map((name, pool) => MapEntry(name, pool.getStatistics()));
  }

  /// Get statistics for a specific pool
  Map<String, dynamic>? getStatistics(String connectionName) {
    return _pools[connectionName]?.getStatistics();
  }

  /// Check if all pools are healthy
  bool get isHealthy {
    return _pools.values.every((pool) => pool.isHealthy);
  }

  /// Close all pools
  Future<void> close() async {
    await Future.wait(_pools.values.map((pool) => pool.close()));
    _pools.clear();
  }

  /// Get list of available pool names
  List<String> get poolNames => _pools.keys.toList();
}
