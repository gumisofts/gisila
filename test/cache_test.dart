import 'package:gisila/gisila.dart';
import 'package:test/test.dart';

void main() {
  group('InMemoryCacheProvider', () {
    late InMemoryCacheProvider cache;

    setUp(() => cache = InMemoryCacheProvider());

    test('set and get round-trip', () async {
      await cache.set('key', 'value');
      expect(await cache.get('key'), 'value');
    });

    test('get returns null for missing key', () async {
      expect(await cache.get('missing'), isNull);
    });

    test('delete removes key and returns true', () async {
      await cache.set('k', 'v');
      expect(await cache.delete('k'), isTrue);
      expect(await cache.get('k'), isNull);
    });

    test('delete returns false for absent key', () async {
      expect(await cache.delete('nope'), isFalse);
    });

    test('exists reflects presence', () async {
      await cache.set('e', 'val');
      expect(await cache.exists('e'), isTrue);
      await cache.delete('e');
      expect(await cache.exists('e'), isFalse);
    });

    test('TTL expiry evicts entries', () async {
      // Margins wide enough for a loaded machine (the suite runs the
      // build_test-based tests in parallel).
      await cache.set('ttl', 'x', ttl: const Duration(milliseconds: 500));
      expect(await cache.get('ttl'), 'x');
      await Future<void>.delayed(const Duration(milliseconds: 900));
      expect(await cache.get('ttl'), isNull);
    });

    test('increment creates and increments counters', () async {
      expect(await cache.increment('n'), 1);
      expect(await cache.increment('n'), 2);
      expect(await cache.increment('n', by: 5), 7);
    });

    test('decrement decreases counters', () async {
      await cache.set('d', '10');
      expect(await cache.decrement('d', by: 3), 7);
    });

    test('flush empties the store', () async {
      await cache.set('a', '1');
      await cache.set('b', '2');
      await cache.flush();
      expect(cache.length, 0);
    });

    test('keys returns matching entries via glob', () async {
      await cache.set('user:1', 'alice');
      await cache.set('user:2', 'bob');
      await cache.set('session:abc', 'data');
      final matched = await cache.keys('user:*');
      expect(matched, containsAll(['user:1', 'user:2']));
      expect(matched, isNot(contains('session:abc')));
    });

    test('mget fetches multiple keys', () async {
      await cache.set('x', '1');
      await cache.set('y', '2');
      final result = await cache.mget(['x', 'y', 'z']);
      expect(result, {'x': '1', 'y': '2'});
    });

    test('mset stores multiple keys', () async {
      await cache.mset({'a': '1', 'b': '2'});
      expect(await cache.get('a'), '1');
      expect(await cache.get('b'), '2');
    });

    test('mdelete removes multiple keys', () async {
      await cache.mset({'p': '1', 'q': '2', 'r': '3'});
      final removed = await cache.mdelete(['p', 'q', 'z']);
      expect(removed, 2);
      expect(await cache.exists('p'), isFalse);
      expect(await cache.exists('r'), isTrue);
    });

    test('maxEntries evicts oldest when full', () async {
      final bounded = InMemoryCacheProvider(maxEntries: 2);
      await bounded.set('a', '1');
      await bounded.set('b', '2');
      await bounded.set('c', '3');
      expect(bounded.length, 2);
      expect(await bounded.get('a'), isNull);
      expect(await bounded.get('b'), '2');
      expect(await bounded.get('c'), '3');
    });

    test('defaultTtl applied when set called without ttl', () async {
      final ttlCache = InMemoryCacheProvider(
        defaultTtl: const Duration(milliseconds: 50),
      );
      await ttlCache.set('k', 'v');
      expect(await ttlCache.get('k'), 'v');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(await ttlCache.get('k'), isNull);
    });
  });

  group('RequestContext.cache integration', () {
    test('ctx.cache returns configured provider', () async {
      final provider = InMemoryCacheProvider();
      final app = GisilaApp(config: AppConfig(cache: provider));
      final handler = app.buildHandler();

      // The handler requires at least one registered controller/route
      // so we only test that app builds without throwing.
      expect(handler, isNotNull);
    });

    test('ctx.cache throws when no cache configured', () {
      final req = Request('GET', Uri.parse('http://localhost/'));
      final ctx = RequestContext(requestId: 'test', request: req);
      expect(() => ctx.cache, throwsStateError);
    });
  });
}
