/// In-process cache provider — no external dependencies required.
library gisila.runtime.cache.in_memory_cache_provider;

import 'cache_provider.dart';

/// A fully in-process [CacheProvider] backed by a plain Dart [Map].
///
/// Suitable for development, tests, single-instance deployments, and
/// as a reference implementation for backend adapters.
///
/// **Not suitable for multi-instance production deployments** — every
/// server process has its own isolated store with no replication.
///
/// ```dart
/// AppConfig(
///   cache: InMemoryCacheProvider(
///     maxEntries: 10000,
///     defaultTtl: Duration(minutes: 15),
///   ),
/// )
/// ```
class InMemoryCacheProvider extends CacheProvider {
  InMemoryCacheProvider({
    this.maxEntries,
    this.defaultTtl,
  });

  /// Maximum number of entries to keep. When the limit is reached the
  /// oldest entry (by insertion order) is evicted before the new one
  /// is added. `null` means unlimited.
  final int? maxEntries;

  /// Default TTL applied when [set] is called without an explicit
  /// [ttl] argument. `null` means entries never expire by default.
  final Duration? defaultTtl;

  final Map<String, _CacheEntry> _store = {};

  @override
  Future<String?> get(String key) async {
    final entry = _store[key];
    if (entry == null) return null;
    if (entry.isExpired) {
      _store.remove(key);
      return null;
    }
    return entry.value;
  }

  @override
  Future<void> set(String key, String value, {Duration? ttl}) async {
    final effectiveTtl = ttl ?? defaultTtl;
    final expiresAt =
        effectiveTtl != null ? DateTime.now().add(effectiveTtl) : null;

    if (maxEntries != null && !_store.containsKey(key)) {
      _evictExpiredEntries();
      if (_store.length >= maxEntries!) {
        _store.remove(_store.keys.first);
      }
    }

    _store[key] = _CacheEntry(value, expiresAt);
  }

  @override
  Future<bool> delete(String key) async {
    return _store.remove(key) != null;
  }

  @override
  Future<bool> exists(String key) async {
    final entry = _store[key];
    if (entry == null) return false;
    if (entry.isExpired) {
      _store.remove(key);
      return false;
    }
    return true;
  }

  @override
  Future<List<String>> keys(String pattern) async {
    _evictExpiredEntries();
    final regex = _globToRegex(pattern);
    return _store.keys.where(regex.hasMatch).toList();
  }

  @override
  Future<void> flush() async => _store.clear();

  @override
  Future<int> increment(String key, {int by = 1}) async {
    final current = int.tryParse(await get(key) ?? '0') ?? 0;
    final next = current + by;
    await set(key, next.toString());
    return next;
  }

  @override
  Future<int> decrement(String key, {int by = 1}) => increment(key, by: -by);

  /// Returns the number of live (non-expired) entries currently in the store.
  int get length {
    _evictExpiredEntries();
    return _store.length;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  void _evictExpiredEntries() {
    _store.removeWhere((_, entry) => entry.isExpired);
  }

  /// Converts a simple glob [pattern] to a [RegExp].
  ///
  /// Supports `*` (any sequence) and `?` (single character). All other
  /// regex-special characters are escaped so literal dots, brackets,
  /// etc. in key names work as expected.
  static RegExp _globToRegex(String pattern) {
    final buffer = StringBuffer('^');
    for (var i = 0; i < pattern.length; i++) {
      final ch = pattern[i];
      switch (ch) {
        case '*':
          buffer.write('.*');
        case '?':
          buffer.write('.');
        default:
          buffer.write(RegExp.escape(ch));
      }
    }
    buffer.write(r'$');
    return RegExp(buffer.toString());
  }
}

class _CacheEntry {
  _CacheEntry(this.value, this.expiresAt);

  final String value;
  final DateTime? expiresAt;

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
}
