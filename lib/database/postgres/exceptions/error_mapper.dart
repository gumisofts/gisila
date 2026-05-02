/// PostgreSQL error code to Dart exception mapper
///
/// This file provides functionality to map PostgreSQL SQLSTATE codes
/// and error details to appropriate Dart exception instances.
library gisila.error_mapper;

import 'package:postgres/postgres.dart' show ServerException;

import 'postgresql_exceptions.dart';

/// Maps PostgreSQL errors to appropriate Dart exceptions
class PostgresErrorMapper {
  /// Map of SQLSTATE codes to exception factory functions
  static const Map<
          String,
          PostgresException Function(
              String, String?, int?, String?, Map<String, dynamic>?)>
      _sqlStateMap = {
    // Class 00: Successful Completion
    '00000': _createSuccessException,

    // Class 01: Warning
    '01000': _createWarningException,
    '0100C': _createWarningException,
    '01008': _createWarningException,
    '01003': _createWarningException,
    '01007': _createWarningException,
    '01006': _createWarningException,
    '01004': _createWarningException,
    '01P01': _createWarningException,

    // Class 02: No Data
    '02000': _createNoDataException,
    '02001': _createNoDataException,

    // Class 08: Connection Exception
    '08000': _createConnectionException,
    '08003': _createConnectionException,
    '08006': _createConnectionException,
    '08001': _createConnectionException,
    '08004': _createConnectionException,
    '08007': _createConnectionException,
    '08P01': _createProtocolViolationException,

    // Class 0A: Feature Not Supported
    '0A000': _createFeatureNotSupportedException,

    // Class 21: Cardinality Violation
    '21000': _createCardinalityViolationException,

    // Class 22: Data Exception
    '22000': _createDataException,
    '22001': _createStringDataTruncationException,
    '22003': _createNumericValueOutOfRangeException,
    '22007': _createInvalidDatetimeException,
    '22008': _createInvalidDatetimeException,
    '22012': _createDivisionByZeroException,
    '22021': _createDataException,
    '22024': _createDataException,
    '22025': _createDataException,
    '2202E': _createDataException,
    '2202F': _createDataException,
    '2202H': _createDataException,

    // Class 23: Integrity Constraint Violation
    '23000': _createIntegrityConstraintViolationException,
    '23001': _createIntegrityConstraintViolationException,
    '23502': _createNotNullViolationException,
    '23503': _createForeignKeyViolationException,
    '23505': _createUniqueViolationException,
    '23514': _createCheckViolationException,
    '23P01': _createExclusionViolationException,

    // Class 24: Invalid Cursor State
    '24000': _createInvalidCursorStateException,

    // Class 25: Invalid Transaction State
    '25000': _createInvalidTransactionStateException,
    '25001': _createInvalidTransactionStateException,
    '25002': _createInvalidTransactionStateException,
    '25008': _createInvalidTransactionStateException,
    '25003': _createInvalidTransactionStateException,
    '25004': _createInvalidTransactionStateException,
    '25005': _createInvalidTransactionStateException,
    '25006': _createInvalidTransactionStateException,
    '25007': _createInvalidTransactionStateException,
    '25P01': _createInvalidTransactionStateException,
    '25P02': _createInvalidTransactionStateException,
  };

  /// Main method to map PostgreSQL errors to Dart exceptions
  static PostgresException mapError(
    String message,
    String? sqlState,
    int? errorCode,
    String? query,
    Map<String, dynamic>? details,
  ) {
    if (sqlState != null && _sqlStateMap.containsKey(sqlState)) {
      return _sqlStateMap[sqlState]!(
          message, sqlState, errorCode, query, details);
    }

    // Return generic exception for unmapped errors
    return PostgresUnknownException(
      message,
      sqlState: sqlState,
      errorCode: errorCode,
      query: query,
      details: details,
    );
  }

  /// Adapt a [ServerException] from `package:postgres` into the
  /// gisila exception hierarchy. The optional [query] argument is
  /// the SQL string that produced the error; it is preserved on the
  /// resulting [PostgresException] for diagnostics.
  static PostgresException fromServerException(
    ServerException e, {
    String? query,
  }) {
    final details = <String, dynamic>{
      if (e.detail != null) 'detail': e.detail,
      if (e.hint != null) 'hint': e.hint,
      if (e.tableName != null) 'table': e.tableName,
      if (e.columnName != null) 'column': e.columnName,
      if (e.constraintName != null) 'constraint': e.constraintName,
      if (e.schemaName != null) 'schema': e.schemaName,
    };
    return mapError(
      e.message,
      e.code,
      null,
      query,
      details.isEmpty ? null : details,
    );
  }

  // =============================================================================
  // FACTORY FUNCTIONS
  // =============================================================================

  /// Create success exception (Class 00)
  static PostgresException _createSuccessException(
    String message,
    String? sqlState,
    int? errorCode,
    String? query,
    Map<String, dynamic>? details,
  ) {
    return PostgresSuccessException(
      message,
      sqlState: sqlState,
      errorCode: errorCode,
      query: query,
      details: details,
    );
  }

  /// Create warning exception (Class 01)
  static PostgresException _createWarningException(
    String message,
    String? sqlState,
    int? errorCode,
    String? query,
    Map<String, dynamic>? details,
  ) {
    return PostgresWarningException(
      message,
      sqlState: sqlState,
      errorCode: errorCode,
      query: query,
      details: details,
    );
  }

  /// Create no data exception (Class 02)
  static PostgresException _createNoDataException(
    String message,
    String? sqlState,
    int? errorCode,
    String? query,
    Map<String, dynamic>? details,
  ) {
    return PostgresNoDataException(
      message,
      sqlState: sqlState,
      errorCode: errorCode,
      query: query,
      details: details,
    );
  }

  /// Create connection exception (Class 08)
  static PostgresException _createConnectionException(
    String message,
    String? sqlState,
    int? errorCode,
    String? query,
    Map<String, dynamic>? details,
  ) {
    return PostgresConnectionException(
      message,
      sqlState: sqlState,
      errorCode: errorCode,
      query: query,
      details: details,
    );
  }

  /// Create protocol violation exception (08P01)
  static PostgresException _createProtocolViolationException(
    String message,
    String? sqlState,
    int? errorCode,
    String? query,
    Map<String, dynamic>? details,
  ) {
    return PostgresProtocolViolationException(
      message,
      sqlState: sqlState,
      errorCode: errorCode,
      query: query,
      details: details,
    );
  }

  /// Create feature not supported exception (Class 0A)
  static PostgresException _createFeatureNotSupportedException(
    String message,
    String? sqlState,
    int? errorCode,
    String? query,
    Map<String, dynamic>? details,
  ) {
    return PostgresFeatureNotSupportedException(
      message,
      sqlState: sqlState,
      errorCode: errorCode,
      query: query,
      details: details,
    );
  }

  /// Create cardinality violation exception (Class 21)
  static PostgresException _createCardinalityViolationException(
    String message,
    String? sqlState,
    int? errorCode,
    String? query,
    Map<String, dynamic>? details,
  ) {
    return PostgresCardinalityViolationException(
      message,
      sqlState: sqlState,
      errorCode: errorCode,
      query: query,
      details: details,
    );
  }

  /// Create data exception (Class 22)
  static PostgresException _createDataException(
    String message,
    String? sqlState,
    int? errorCode,
    String? query,
    Map<String, dynamic>? details,
  ) {
    return PostgresDataException(
      message,
      sqlState: sqlState,
      errorCode: errorCode,
      query: query,
      details: details,
    );
  }

  /// Create string data truncation exception (22001)
  static PostgresException _createStringDataTruncationException(
    String message,
    String? sqlState,
    int? errorCode,
    String? query,
    Map<String, dynamic>? details,
  ) {
    return PostgresStringDataTruncationException(
      message,
      sqlState: sqlState,
      errorCode: errorCode,
      query: query,
      details: details,
    );
  }

  /// Create numeric value out of range exception (22003)
  static PostgresException _createNumericValueOutOfRangeException(
    String message,
    String? sqlState,
    int? errorCode,
    String? query,
    Map<String, dynamic>? details,
  ) {
    return PostgresNumericValueOutOfRangeException(
      message,
      sqlState: sqlState,
      errorCode: errorCode,
      query: query,
      details: details,
    );
  }

  /// Create invalid datetime exception (22007, 22008)
  static PostgresException _createInvalidDatetimeException(
    String message,
    String? sqlState,
    int? errorCode,
    String? query,
    Map<String, dynamic>? details,
  ) {
    return PostgresInvalidDatetimeException(
      message,
      sqlState: sqlState,
      errorCode: errorCode,
      query: query,
      details: details,
    );
  }

  /// Create division by zero exception (22012)
  static PostgresException _createDivisionByZeroException(
    String message,
    String? sqlState,
    int? errorCode,
    String? query,
    Map<String, dynamic>? details,
  ) {
    return PostgresDivisionByZeroException(
      message,
      sqlState: sqlState,
      errorCode: errorCode,
      query: query,
      details: details,
    );
  }

  /// Create integrity constraint violation exception (Class 23)
  static PostgresException _createIntegrityConstraintViolationException(
    String message,
    String? sqlState,
    int? errorCode,
    String? query,
    Map<String, dynamic>? details,
  ) {
    return PostgresIntegrityConstraintViolationException(
      message,
      sqlState: sqlState,
      errorCode: errorCode,
      query: query,
      details: details,
    );
  }

  /// Create not null violation exception (23502)
  static PostgresException _createNotNullViolationException(
    String message,
    String? sqlState,
    int? errorCode,
    String? query,
    Map<String, dynamic>? details,
  ) {
    return PostgresNotNullViolationException(
      message,
      sqlState: sqlState,
      errorCode: errorCode,
      query: query,
      details: details,
    );
  }

  /// Create foreign key violation exception (23503)
  static PostgresException _createForeignKeyViolationException(
    String message,
    String? sqlState,
    int? errorCode,
    String? query,
    Map<String, dynamic>? details,
  ) {
    return PostgresForeignKeyViolationException(
      message,
      sqlState: sqlState,
      errorCode: errorCode,
      query: query,
      details: details,
    );
  }

  /// Create unique violation exception (23505)
  static PostgresException _createUniqueViolationException(
    String message,
    String? sqlState,
    int? errorCode,
    String? query,
    Map<String, dynamic>? details,
  ) {
    return PostgresUniqueViolationException(
      message,
      sqlState: sqlState,
      errorCode: errorCode,
      query: query,
      details: details,
    );
  }

  /// Create check violation exception (23514)
  static PostgresException _createCheckViolationException(
    String message,
    String? sqlState,
    int? errorCode,
    String? query,
    Map<String, dynamic>? details,
  ) {
    return PostgresCheckViolationException(
      message,
      sqlState: sqlState,
      errorCode: errorCode,
      query: query,
      details: details,
    );
  }

  /// Create exclusion violation exception (23P01)
  static PostgresException _createExclusionViolationException(
    String message,
    String? sqlState,
    int? errorCode,
    String? query,
    Map<String, dynamic>? details,
  ) {
    return PostgresExclusionViolationException(
      message,
      sqlState: sqlState,
      errorCode: errorCode,
      query: query,
      details: details,
    );
  }

  /// Create invalid cursor state exception (Class 24)
  static PostgresException _createInvalidCursorStateException(
    String message,
    String? sqlState,
    int? errorCode,
    String? query,
    Map<String, dynamic>? details,
  ) {
    return PostgresInvalidCursorStateException(
      message,
      sqlState: sqlState,
      errorCode: errorCode,
      query: query,
      details: details,
    );
  }

  /// Create invalid transaction state exception (Class 25)
  static PostgresException _createInvalidTransactionStateException(
    String message,
    String? sqlState,
    int? errorCode,
    String? query,
    Map<String, dynamic>? details,
  ) {
    return PostgresInvalidTransactionStateException(
      message,
      sqlState: sqlState,
      errorCode: errorCode,
      query: query,
      details: details,
    );
  }
}
