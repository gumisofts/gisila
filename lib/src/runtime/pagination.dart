/// Pagination helpers: validated page parameters, opaque cursors and one
/// response shape for lists.
library gisila.runtime.pagination;

import 'dart:convert';

import 'exceptions.dart';

/// Validated `limit` / `offset` / `cursor` query parameters.
///
/// ```dart
/// @Get('/')
/// Future<Page<Post>> list({int? limit, int? offset}) async {
///   final page = PageParams(limit: limit, offset: offset);
///   final rows = await posts.list(limit: page.limit, offset: page.offset);
///   return Page(rows, params: page, total: await posts.count());
/// }
/// ```
///
/// A missing `limit` becomes [defaultLimit]; one above [maxLimit] is cut
/// down to it, so a client can't ask for everything at once. Negative
/// values or a zero limit are a 400.
class PageParams {
  PageParams({
    int? limit,
    int? offset,
    this.cursor,
    int defaultLimit = 25,
    int maxLimit = 100,
    int maxOffset = 100000,
  })  : limit = _limit(limit, defaultLimit, maxLimit),
        offset = _offset(offset, maxOffset);

  final int limit;
  final int offset;

  /// The opaque cursor the client sent back, if any (see [Cursor]).
  final String? cursor;

  static int _limit(int? limit, int defaultLimit, int maxLimit) {
    if (limit == null) return defaultLimit;
    if (limit < 1) {
      throw BadRequest('limit must be at least 1', code: 'invalid_limit');
    }
    return limit > maxLimit ? maxLimit : limit;
  }

  static int _offset(int? offset, int maxOffset) {
    if (offset == null) return 0;
    if (offset < 0 || offset > maxOffset) {
      throw BadRequest('offset must be between 0 and $maxOffset',
          code: 'invalid_offset');
    }
    return offset;
  }
}

/// Opaque cursors for keyset pagination: the position (say, the last
/// row's sort key and id) is JSON-encoded and base64url'd, so clients pass
/// it back without depending on its shape.
///
/// Cursors aren't signed: decode them only into values you would accept
/// from the client anyway, and keep authorization in the query.
abstract final class Cursor {
  static String encode(Map<String, Object?> position) =>
      base64Url.encode(utf8.encode(jsonEncode(position))).replaceAll('=', '');

  /// The position in [cursor]. A malformed cursor is a 400
  /// (`invalid_cursor`), not a 500.
  static Map<String, Object?> decode(String cursor) {
    try {
      final json = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(cursor))));
      if (json is Map<String, Object?>) return json;
    } catch (_) {
      // Fall through to the 400.
    }
    throw BadRequest('Malformed cursor', code: 'invalid_cursor');
  }
}

/// One page of a list, rendered as
/// `{"items": [...], "page": {"limit", "offset", "total", "next_cursor",
/// "has_more"}}` (keys without a value are left out).
class Page<T> {
  Page(
    Iterable<T> items, {
    PageParams? params,
    int? limit,
    int? offset,
    this.total,
    this.nextCursor,
    bool? hasMore,
  })  : items = List.unmodifiable(items),
        limit = limit ?? params?.limit,
        offset = offset ?? (params?.cursor == null ? params?.offset : null),
        hasMore = hasMore ?? _hasMore(items.length, total, nextCursor,
            offset ?? params?.offset, limit ?? params?.limit);

  final List<T> items;
  final int? limit;
  final int? offset;
  final int? total;
  final String? nextCursor;
  final bool hasMore;

  static bool _hasMore(
      int count, int? total, String? next, int? offset, int? limit) {
    if (next != null) return true;
    if (total != null) return (offset ?? 0) + count < total;
    return limit != null && count >= limit;
  }

  /// Items are encoded the way handler results are (their `toJson()`).
  Map<String, Object?> toJson() => <String, Object?>{
        'items': items,
        'page': <String, Object?>{
          if (limit != null) 'limit': limit,
          if (offset != null) 'offset': offset,
          if (total != null) 'total': total,
          if (nextCursor != null) 'next_cursor': nextCursor,
          'has_more': hasMore,
        },
      };
}
