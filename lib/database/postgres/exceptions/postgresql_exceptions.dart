/// Comprehensive PostgreSQL exception mapping for Dart
///
/// This file provides a complete mapping from PostgreSQL SQLSTATE codes
/// to appropriate Dart exceptions with detailed error information.
library gisila.postgresql_exceptions;

/// Base class for all PostgreSQL-related exceptions
abstract class PostgresException implements Exception {
  /// The original PostgreSQL error message
  final String message;

  /// The PostgreSQL SQLSTATE code (5-character error code)
  final String? sqlState;

  /// The PostgreSQL error code (numeric)
  final int? errorCode;

  /// The SQL query that caused the error (if available)
  final String? query;

  /// Additional error details from PostgreSQL
  final Map<String, dynamic>? details;

  const PostgresException(
    this.message, {
    this.sqlState,
    this.errorCode,
    this.query,
    this.details,
  });

  @override
  String toString() {
    final buffer = StringBuffer(runtimeType.toString());
    buffer.write(': $message');

    if (sqlState != null) {
      buffer.write(' (SQLSTATE: $sqlState)');
    }

    if (errorCode != null) {
      buffer.write(' (Error Code: $errorCode)');
    }

    return buffer.toString();
  }
}

/// Exception for connection-related errors (Class 08)
class PostgresConnectionException extends PostgresException {
  const PostgresConnectionException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
  });
}

/// Exception for data integrity constraint violations (Class 23)
class PostgresIntegrityConstraintViolationException extends PostgresException {
  /// The name of the constraint that was violated (if available)
  final String? constraintName;

  /// The table involved in the constraint violation (if available)
  final String? tableName;

  /// The column involved in the constraint violation (if available)
  final String? columnName;

  const PostgresIntegrityConstraintViolationException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
    this.constraintName,
    this.tableName,
    this.columnName,
  });
}

/// Exception for unique constraint violations (SQLSTATE 23505)
class PostgresUniqueViolationException
    extends PostgresIntegrityConstraintViolationException {
  const PostgresUniqueViolationException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
    super.constraintName,
    super.tableName,
    super.columnName,
  });
}

/// Exception for foreign key constraint violations (SQLSTATE 23503, 23000)
class PostgresForeignKeyViolationException
    extends PostgresIntegrityConstraintViolationException {
  /// The referenced table in the foreign key constraint
  final String? referencedTable;

  /// The referenced column in the foreign key constraint
  final String? referencedColumn;

  const PostgresForeignKeyViolationException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
    super.constraintName,
    super.tableName,
    super.columnName,
    this.referencedTable,
    this.referencedColumn,
  });
}

/// Exception for not null constraint violations (SQLSTATE 23502)
class PostgresNotNullViolationException
    extends PostgresIntegrityConstraintViolationException {
  const PostgresNotNullViolationException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
    super.constraintName,
    super.tableName,
    super.columnName,
  });
}

/// Exception for check constraint violations (SQLSTATE 23514)
class PostgresCheckViolationException
    extends PostgresIntegrityConstraintViolationException {
  const PostgresCheckViolationException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
    super.constraintName,
    super.tableName,
    super.columnName,
  });
}

/// Exception for exclusion constraint violations (SQLSTATE 23P01)
class PostgresExclusionViolationException
    extends PostgresIntegrityConstraintViolationException {
  const PostgresExclusionViolationException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
    super.constraintName,
    super.tableName,
    super.columnName,
  });
}

/// Exception for syntax errors and access rule violations (Class 42)
class PostgresSyntaxException extends PostgresException {
  const PostgresSyntaxException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
  });
}

/// Exception for undefined table errors (SQLSTATE 42P01)
class PostgresUndefinedTableException extends PostgresSyntaxException {
  /// The name of the undefined table
  final String? tableName;

  const PostgresUndefinedTableException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
    this.tableName,
  });
}

/// Exception for undefined column errors (SQLSTATE 42703)
class PostgresUndefinedColumnException extends PostgresSyntaxException {
  /// The name of the undefined column
  final String? columnName;

  /// The table where the column was expected
  final String? tableName;

  const PostgresUndefinedColumnException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
    this.columnName,
    this.tableName,
  });
}

/// Exception for insufficient privilege errors (SQLSTATE 42501)
class PostgresInsufficientPrivilegeException extends PostgresSyntaxException {
  /// The type of operation that was denied
  final String? operation;

  /// The object on which the operation was denied
  final String? objectName;

  const PostgresInsufficientPrivilegeException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
    this.operation,
    this.objectName,
  });
}

/// Exception for data type-related errors (Class 22)
class PostgresDataException extends PostgresException {
  const PostgresDataException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
  });
}

/// Exception for numeric value out of range (SQLSTATE 22003)
class PostgresNumericValueOutOfRangeException extends PostgresDataException {
  const PostgresNumericValueOutOfRangeException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
  });
}

/// Exception for invalid datetime format (SQLSTATE 22007, 22008)
class PostgresInvalidDatetimeException extends PostgresDataException {
  const PostgresInvalidDatetimeException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
  });
}

/// Exception for division by zero (SQLSTATE 22012)
class PostgresDivisionByZeroException extends PostgresDataException {
  const PostgresDivisionByZeroException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
  });
}

/// Exception for string data truncation (SQLSTATE 22001)
class PostgresStringDataTruncationException extends PostgresDataException {
  const PostgresStringDataTruncationException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
  });
}

/// Exception for transaction-related errors (Class 25, 40)
class PostgresTransactionException extends PostgresException {
  const PostgresTransactionException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
  });
}

/// Exception for serialization failures (SQLSTATE 40001)
class PostgresSerializationFailureException
    extends PostgresTransactionException {
  const PostgresSerializationFailureException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
  });
}

/// Exception for deadlock detection (SQLSTATE 40P01)
class PostgresDeadlockDetectedException extends PostgresTransactionException {
  const PostgresDeadlockDetectedException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
  });
}

/// Exception for lock timeout (SQLSTATE custom, error 1205 in MySQL mapping)
class PostgresLockTimeoutException extends PostgresTransactionException {
  const PostgresLockTimeoutException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
  });
}

/// Exception for invalid transaction state (SQLSTATE 25000)
class PostgresInvalidTransactionStateException
    extends PostgresTransactionException {
  const PostgresInvalidTransactionStateException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
  });
}

/// Exception for system errors (Class 53, 54, 58)
class PostgresSystemException extends PostgresException {
  const PostgresSystemException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
  });
}

/// Exception for insufficient resources (SQLSTATE 53000, 53200)
class PostgresInsufficientResourcesException extends PostgresSystemException {
  const PostgresInsufficientResourcesException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
  });
}

/// Exception for disk full (SQLSTATE 53100)
class PostgresDiskFullException extends PostgresSystemException {
  const PostgresDiskFullException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
  });
}

/// Exception for too many connections (SQLSTATE 53300)
class PostgresTooManyConnectionsException extends PostgresSystemException {
  const PostgresTooManyConnectionsException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
  });
}

/// Exception for program limits exceeded (SQLSTATE 54000, 54001)
class PostgresProgramLimitExceededException extends PostgresSystemException {
  const PostgresProgramLimitExceededException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
  });
}

/// Exception for authentication-related errors (Class 28)
class PostgresAuthenticationException extends PostgresException {
  const PostgresAuthenticationException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
  });
}

/// Exception for invalid authorization specification (SQLSTATE 28000)
class PostgresInvalidAuthorizationException
    extends PostgresAuthenticationException {
  const PostgresInvalidAuthorizationException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
  });
}

/// Exception for invalid password (SQLSTATE 28P01)
class PostgresInvalidPasswordException extends PostgresAuthenticationException {
  const PostgresInvalidPasswordException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
  });
}

/// Exception for cursor-related errors (Class 24)
class PostgresCursorException extends PostgresException {
  const PostgresCursorException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
  });
}

/// Exception for invalid cursor state (SQLSTATE 24000)
class PostgresInvalidCursorStateException extends PostgresCursorException {
  const PostgresInvalidCursorStateException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
  });
}

/// Exception for feature not supported (Class 0A)
class PostgresFeatureNotSupportedException extends PostgresException {
  const PostgresFeatureNotSupportedException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
  });
}

/// Exception for protocol violations (SQLSTATE 08P01)
class PostgresProtocolViolationException extends PostgresConnectionException {
  const PostgresProtocolViolationException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
  });
}

/// Exception for configuration file errors (Class F0)
class PostgresConfigFileException extends PostgresSystemException {
  const PostgresConfigFileException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
  });
}

/// Exception for internal errors (Class XX)
class PostgresInternalException extends PostgresException {
  const PostgresInternalException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
  });
}

/// Exception for warnings (Class 01) - Note: These might not always be thrown as exceptions
class PostgresWarningException extends PostgresException {
  const PostgresWarningException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
  });
}

/// Exception for successful completion with additional info (Class 00)
class PostgresSuccessException extends PostgresException {
  const PostgresSuccessException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
  });
}

/// Exception for no data found (Class 02)
class PostgresNoDataException extends PostgresException {
  const PostgresNoDataException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
  });
}

/// Exception for cardinality violations (Class 21)
class PostgresCardinalityViolationException extends PostgresException {
  const PostgresCardinalityViolationException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
  });
}

/// Exception for savepoint-related errors (Class 3B)
class PostgresSavepointException extends PostgresException {
  const PostgresSavepointException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
  });
}

/// Exception for PL/pgSQL errors (Class P0)
class PostgresPlPgSqlException extends PostgresException {
  const PostgresPlPgSqlException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
  });
}

/// Exception for external routine errors (Class 38, 39)
class PostgresExternalRoutineException extends PostgresException {
  const PostgresExternalRoutineException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
  });
}

/// Exception for operator intervention (Class 57)
class PostgresOperatorInterventionException extends PostgresException {
  const PostgresOperatorInterventionException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
  });
}

/// Exception for query cancelled (SQLSTATE 57014)
class PostgresQueryCancelledException
    extends PostgresOperatorInterventionException {
  const PostgresQueryCancelledException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
  });
}

/// Generic exception for unrecognized or unmapped PostgreSQL errors
class PostgresUnknownException extends PostgresException {
  const PostgresUnknownException(
    super.message, {
    super.sqlState,
    super.errorCode,
    super.query,
    super.details,
  });
}
