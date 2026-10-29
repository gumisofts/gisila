import 'dart:convert';

import 'package:gisila/gisila.dart';
import 'package:test/test.dart';

class _Post {
  _Post(this.id);
  final int id;
  Map<String, Object?> toJson() => {'id': id};
}

Matcher _badRequest(String code) => throwsA(isA<HttpException>()
    .having((e) => e.statusCode, 'statusCode', 400)
    .having((e) => e.code, 'code', code));

Future<Object?> _render(Object page) async =>
    jsonDecode(await jsonResponse(body: page).readAsString());

void main() {
  group('PageParams', () {
    test('defaults, clamps and validates', () {
      final d = PageParams();
      expect([d.limit, d.offset], [25, 0]);
      expect(PageParams(limit: 500).limit, 100);
      expect(PageParams(limit: 10, offset: 30).offset, 30);
      expect(PageParams(defaultLimit: 5, maxLimit: 8, limit: 9).limit, 8);
      expect(() => PageParams(limit: 0), _badRequest('invalid_limit'));
      expect(() => PageParams(offset: -1), _badRequest('invalid_offset'));
      expect(() => PageParams(offset: 100001), _badRequest('invalid_offset'));
    });
  });

  group('Cursor', () {
    test('round-trips a position', () {
      final c = Cursor.encode({'created': '2026-10-30T00:00:00Z', 'id': 42});
      expect(c, isNot(contains('=')));
      expect(Cursor.decode(c), {'created': '2026-10-30T00:00:00Z', 'id': 42});
    });

    test('garbage is a 400', () {
      final notAMap = base64Url.encode(utf8.encode('[1]'));
      for (final bad in ['!!!', 'bm90IGpzb24', notAMap]) {
        expect(() => Cursor.decode(bad), _badRequest('invalid_cursor'),
            reason: bad);
      }
    });
  });

  group('Page', () {
    test('offset pages render items via toJson and compute has_more',
        () async {
      final params = PageParams(limit: 2, offset: 2);
      expect(
          await _render(Page([_Post(3), _Post(4)], params: params, total: 5)),
          {
            'items': [
              {'id': 3},
              {'id': 4}
            ],
            'page': {'limit': 2, 'offset': 2, 'total': 5, 'has_more': true},
          });
      final last =
          Page([_Post(5)], params: PageParams(limit: 2, offset: 4), total: 5);
      expect(last.hasMore, isFalse);
    });

    test('cursor pages drop the offset and carry next_cursor', () async {
      final params = PageParams(limit: 2, cursor: Cursor.encode({'id': 2}));
      final next = Cursor.encode({'id': 4});
      final page = Page([_Post(3), _Post(4)], params: params, nextCursor: next);
      expect(await _render(page), {
        'items': [
          {'id': 3},
          {'id': 4}
        ],
        'page': {'limit': 2, 'next_cursor': next, 'has_more': true},
      });
      expect(Page<int>([], params: params).hasMore, isFalse);
    });

    test('without total, a full page may have more', () {
      final params = PageParams(limit: 2);
      expect(Page([1, 2], params: params).hasMore, isTrue);
      expect(Page([1], params: params).hasMore, isFalse);
      expect(Page([1], hasMore: true).hasMore, isTrue);
    });
  });
}
