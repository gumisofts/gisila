import 'dart:convert';

import 'package:gisila/gisila.dart';
import 'package:test/test.dart';

void main() {
  group('ConsoleLogger', () {
    test('respects level threshold', () {
      final lines = <String>[];
      final logger = ConsoleLogger(
        level: LogLevel.warning,
        stdoutSink: lines.add,
        stderrSink: lines.add,
      );
      logger.info('skip me');
      logger.warning('keep me');
      expect(lines, hasLength(1));
      expect(lines.single, contains('keep me'));
    });

    test('text format includes level and message', () {
      final lines = <String>[];
      final logger = ConsoleLogger(
        format: LogFormat.text,
        stdoutSink: lines.add,
        stderrSink: lines.add,
      );
      logger.info('hello', fields: <String, Object?>{'user': 'alice'});
      expect(lines, hasLength(1));
      expect(lines.single, contains('[INFO ]'));
      expect(lines.single, contains('hello'));
      expect(lines.single, contains('user=alice'));
    });

    test('JSON format produces parseable records', () {
      final lines = <String>[];
      final logger = ConsoleLogger(
        format: LogFormat.json,
        stdoutSink: lines.add,
        stderrSink: lines.add,
      );
      logger.warning(
        'oops',
        fields: <String, Object?>{'where': 'codec'},
      );
      final record = jsonDecode(lines.single) as Map<String, dynamic>;
      expect(record['level'], 'warning');
      expect(record['msg'], 'oops');
      expect(record['where'], 'codec');
      expect(record['ts'], isA<String>());
    });
  });
}
