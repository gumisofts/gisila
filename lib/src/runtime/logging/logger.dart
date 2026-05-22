/// Logger abstraction with a built-in console implementation.
library gisila.runtime.logging.logger;

import 'dart:convert';
import 'dart:io';

import 'log_event.dart';

/// Pluggable sink for [LogEvent]s. Swap this out via [AppConfig.logger]
/// to ship logs to OpenTelemetry / a file / etc.
abstract class Logger {
  Logger();

  /// Minimum severity the logger will emit. Defaults to [LogLevel.info].
  LogLevel get level;

  /// Emits [event]. Implementations should respect [level] (calls
  /// below the threshold should be cheap to drop).
  void log(LogEvent event);

  // Convenience helpers ----------------------------------------------------

  void trace(String message, {Map<String, Object?>? fields}) =>
      _emit(LogLevel.trace, message, fields: fields);
  void debug(String message, {Map<String, Object?>? fields}) =>
      _emit(LogLevel.debug, message, fields: fields);
  void info(String message, {Map<String, Object?>? fields}) =>
      _emit(LogLevel.info, message, fields: fields);
  void warning(String message,
          {Map<String, Object?>? fields,
          Object? error,
          StackTrace? stackTrace}) =>
      _emit(LogLevel.warning, message,
          fields: fields, error: error, stackTrace: stackTrace);
  void error(String message,
          {Map<String, Object?>? fields,
          Object? error,
          StackTrace? stackTrace}) =>
      _emit(LogLevel.error, message,
          fields: fields, error: error, stackTrace: stackTrace);
  void fatal(String message,
          {Map<String, Object?>? fields,
          Object? error,
          StackTrace? stackTrace}) =>
      _emit(LogLevel.fatal, message,
          fields: fields, error: error, stackTrace: stackTrace);

  void _emit(
    LogLevel lvl,
    String message, {
    Map<String, Object?>? fields,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!(lvl >= level)) return;
    log(LogEvent(
      level: lvl,
      message: message,
      timestamp: DateTime.now().toUtc(),
      fields: fields,
      error: error,
      stackTrace: stackTrace,
    ));
  }
}

/// Default console logger. Writes to `stdout` (and `stderr` for
/// warnings and above).
class ConsoleLogger extends Logger {
  ConsoleLogger({
    this.level = LogLevel.info,
    this.format = LogFormat.text,
    void Function(String line)? stdoutSink,
    void Function(String line)? stderrSink,
  })  : _stdout = stdoutSink ?? _defaultStdout,
        _stderr = stderrSink ?? _defaultStderr;

  @override
  final LogLevel level;
  final LogFormat format;

  final void Function(String line) _stdout;
  final void Function(String line) _stderr;

  static void _defaultStdout(String line) {
    stdout.writeln(line);
  }

  static void _defaultStderr(String line) {
    stderr.writeln(line);
  }

  @override
  void log(LogEvent event) {
    if (!(event.level >= level)) return;
    final line = format == LogFormat.json ? _formatJson(event) : _formatText(event);
    if (event.level.priority >= LogLevel.warning.priority) {
      _stderr(line);
    } else {
      _stdout(line);
    }
  }

  String _formatText(LogEvent e) {
    final buf = StringBuffer()
      ..write(e.timestamp.toIso8601String())
      ..write(' [')
      ..write(e.level.name.toUpperCase().padRight(5))
      ..write(']');
    if (e.requestId != null) buf..write(' req=')..write(e.requestId);
    if (e.principalId != null) buf..write(' user=')..write(e.principalId);
    buf..write(' ')..write(e.message);
    if (e.fields.isNotEmpty) {
      buf.write(' ');
      var first = true;
      for (final entry in e.fields.entries) {
        if (!first) buf.write(' ');
        first = false;
        buf..write(entry.key)..write('=')..write(entry.value);
      }
    }
    if (e.error != null) buf..write(' error=')..write(e.error);
    return buf.toString();
  }

  String _formatJson(LogEvent e) => jsonEncode(<String, Object?>{
        'ts': e.timestamp.toIso8601String(),
        'level': e.level.name,
        'msg': e.message,
        if (e.requestId != null) 'requestId': e.requestId,
        if (e.principalId != null) 'principalId': e.principalId,
        if (e.error != null) 'error': e.error.toString(),
        if (e.stackTrace != null) 'stack': e.stackTrace.toString(),
        ...e.fields,
      });
}
