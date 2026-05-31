/// Translates driver-specific database errors into [HttpException]s.
///
/// Configured via `AppConfig.dbErrorMapper` and consulted by the
/// framework's error middleware **before** the generic `500` fallback.
/// Each app supplies its own mapper - the framework does not ship a
/// Postgres- (or any other driver-) specific implementation, on
/// purpose: gisila core has no DB driver dependency.
library gisila.runtime.db.db_error_mapper;

import '../exceptions.dart';

/// Maps an uncaught exception into an [HttpException] if the mapper
/// recognises it as a database driver error; returns `null` otherwise
/// so the framework can apply its next-best mapping strategy.
abstract class DbErrorMapper {
  const DbErrorMapper();

  /// Returns an [HttpException] describing [error] in HTTP terms, or
  /// `null` if [error] is not a recognised database error.
  HttpException? map(Object error, StackTrace stack);
}
