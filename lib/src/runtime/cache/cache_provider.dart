/// Pluggable cache provider.
///
/// Implement this class to connect any cache backend — Redis, Memcached,
/// an in-process LRU map, etc. — to the gisila framework.
///
/// The framework calls [connect] once when the server starts and
/// [disconnect] once when it stops. Between those calls every request
/// can reach the provider through `ctx.cache`.
///
/// Example (minimal in-process cache):
///
/// ```dart
/// class InMemoryCacheProvider extends CacheProvider { ... }
///
/// final app = GisilaApp(
///   config: AppConfig(cache: InMemoryCacheProvider()),
/// );
/// ```
///
/// Third-party adapters (e.g. `gisila_redis`, `gisila_memcached`) follow
/// the same interface so switching backends is a one-line change in
/// [AppConfig].
library gisila.runtime.cache.cache_provider;

/// Pluggable cache backend.
///
/// All methods are asynchronous so implementations can wrap network
/// clients without blocking. The framework does not impose a
/// per-request lifecycle on the cache (unlike [DatabaseProvider]):
/// the same [CacheProvider] instance serves every request.
///
/// **Key contract**
///
/// Keys are plain strings. Values are UTF-8 strings; callers are
/// responsible for encoding/decoding structured data (e.g. via
/// `dart:convert` `jsonEncode` / `jsonDecode`).
///
/// **TTL**
///
/// A `null` [ttl] means the entry should never expire. Backends that
/// cannot honour this (e.g. those with a mandatory max TTL) must
/// document the limitation.
abstract class CacheProvider {
  const CacheProvider();

  /// Called once when the application starts.
  ///
  /// Use this to open connection pools, authenticate to the backend,
  /// warm caches, etc. The framework awaits completion before
  /// starting the HTTP server, so slow connections surface as startup
  /// errors rather than per-request failures.
  Future<void> connect() async {}

  /// Called once when the application stops.
  ///
  /// Release connections, flush write-back buffers, etc. The framework
  /// awaits completion before the process exits.
  Future<void> disconnect() async {}

  // ---------------------------------------------------------------------------
  // Core key/value operations
  // ---------------------------------------------------------------------------

  /// Returns the value stored under [key], or `null` if the key is
  /// absent or has expired.
  Future<String?> get(String key);

  /// Stores [value] under [key].
  ///
  /// If [ttl] is supplied the entry is automatically evicted after
  /// that duration. Pass `null` to keep the entry indefinitely.
  Future<void> set(String key, String value, {Duration? ttl});

  /// Removes [key] from the cache.
  ///
  /// Returns `true` if the key existed (and was removed), `false` if
  /// it was already absent.
  Future<bool> delete(String key);

  /// Returns `true` if [key] is present and has not expired.
  Future<bool> exists(String key);

  // ---------------------------------------------------------------------------
  // Bulk / utility operations
  // ---------------------------------------------------------------------------

  /// Returns every key whose name matches [pattern].
  ///
  /// [pattern] follows glob syntax: `*` matches any sequence of
  /// characters, `?` matches a single character. Examples:
  ///
  /// ```
  /// 'user:*'          // all keys starting with "user:"
  /// 'session:??:info' // session keys with a 2-char segment
  /// ```
  ///
  /// Implementations that cannot enumerate keys efficiently (e.g.
  /// append-only stores) should return an empty list and document the
  /// limitation.
  Future<List<String>> keys(String pattern);

  /// Removes every key from the cache.
  ///
  /// Use with caution in production; this is intended for tests and
  /// administrative tooling.
  Future<void> flush();

  // ---------------------------------------------------------------------------
  // Atomic counters
  // ---------------------------------------------------------------------------

  /// Atomically increments the integer counter stored at [key] by
  /// [by] and returns the new value.
  ///
  /// If [key] does not exist it is treated as `0` before the
  /// increment. Throws [FormatException] if the stored value is not
  /// a valid integer.
  Future<int> increment(String key, {int by = 1});

  /// Atomically decrements the integer counter stored at [key] by
  /// [by] and returns the new value.
  ///
  /// Equivalent to `increment(key, by: -by)`.
  Future<int> decrement(String key, {int by = 1});

  // ---------------------------------------------------------------------------
  // Multi-key helpers
  // ---------------------------------------------------------------------------

  /// Fetches multiple keys in one logical operation.
  ///
  /// Returns a map from key to value; absent or expired keys are
  /// omitted. The default implementation calls [get] in parallel;
  /// backends with a native multi-get command should override this.
  Future<Map<String, String>> mget(List<String> keys) async {
    final entries = await Future.wait(
      keys.map((k) async {
        final v = await get(k);
        return v != null ? MapEntry(k, v) : null;
      }),
    );
    return Map.fromEntries(entries.whereType<MapEntry<String, String>>());
  }

  /// Stores multiple key/value pairs in one logical operation.
  ///
  /// All entries share the same [ttl]. The default implementation
  /// calls [set] in parallel; backends with a native multi-set should
  /// override this.
  Future<void> mset(
    Map<String, String> entries, {
    Duration? ttl,
  }) async {
    await Future.wait(
      entries.entries.map((e) => set(e.key, e.value, ttl: ttl)),
    );
  }

  /// Removes multiple keys in one logical operation.
  ///
  /// Returns the number of keys that existed (and were removed). The
  /// default implementation calls [delete] in parallel.
  Future<int> mdelete(List<String> keys) async {
    final results = await Future.wait(keys.map(delete));
    return results.where((r) => r).length;
  }
}
