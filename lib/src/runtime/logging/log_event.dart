/// Structured log event.
library gisila.runtime.logging.log_event;

/// Severity levels, ordered from most verbose to least.
enum LogLevel {
  trace(0),
  debug(1),
  info(2),
  warning(3),
  error(4),
  fatal(5),
  off(6);

  const LogLevel(this.priority);
  final int priority;

  bool operator >=(LogLevel other) => priority >= other.priority;
}

/// On-the-wire format used by the [ConsoleLogger].
enum LogFormat { text, json }

/// A single structured log record handed to a [Logger].
class LogEvent {
  LogEvent({
    required this.level,
    required this.message,
    required this.timestamp,
    this.requestId,
    this.principalId,
    this.error,
    this.stackTrace,
    Map<String, Object?>? fields,
  }) : fields = fields ?? const <String, Object?>{};

  final LogLevel level;
  final String message;
  final DateTime timestamp;

  /// Pulled from the active [RequestContext] when the call is logged
  /// inside a request scope; otherwise `null`.
  final String? requestId;
  final String? principalId;

  final Object? error;
  final StackTrace? stackTrace;

  /// Arbitrary key/value pairs serialised by the formatter.
  final Map<String, Object?> fields;
}
