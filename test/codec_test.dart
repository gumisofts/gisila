import 'package:gisila/gisila.dart';
import 'package:test/test.dart';

void main() {
  group('coerce<T>', () {
    test('parses int / double / bool / DateTime', () {
      expect(coerce<int>('42', 'x', required: true), 42);
      expect(coerce<double>('1.5', 'x', required: true), 1.5);
      expect(coerce<bool>('true', 'x', required: true), isTrue);
      expect(coerce<bool>('0', 'x', required: true), isFalse);
      expect(coerce<DateTime>('2026-01-01T00:00:00Z', 'x', required: true),
          DateTime.utc(2026, 1, 1));
    });

    test('returns null for missing optional', () {
      expect(coerce<int?>(null, 'x', required: false), isNull);
      expect(coerce<String?>(null, 'x', required: false), isNull);
    });

    test('throws BadRequestException for missing required', () {
      expect(
        () => coerce<int>(null, 'x', required: true),
        throwsA(isA<BadRequestException>()),
      );
    });

    test('throws BadRequestException on invalid format', () {
      expect(
        () => coerce<int>('abc', 'x', required: true),
        throwsA(isA<BadRequestException>()),
      );
    });

    test('BadRequestException is itself an HttpException', () {
      expect(BadRequestException('boom'), isA<HttpException>());
      expect(BadRequestException('boom').statusCode, 400);
    });
  });

  group('jsonResponse', () {
    test('serialises maps and DateTime', () async {
      final res = jsonResponse(body: <String, Object?>{
        'when': DateTime.utc(2026, 1, 2),
        'count': 3,
      });
      expect(res.statusCode, 200);
      final body = await res.readAsString();
      expect(body, contains('"when":"2026-01-02T00:00:00.000Z"'));
      expect(body, contains('"count":3'));
    });

    test('walks toJson() recursively', () async {
      final res = jsonResponse(body: _Demo('alice'));
      expect(await res.readAsString(), '{"name":"alice"}');
    });
  });
}

class _Demo {
  _Demo(this.name);
  final String name;
  Map<String, Object?> toJson() => <String, Object?>{'name': name};
}
