/// Side-channel storage for preloaded relations.
///
/// Generated model classes mix in [Preloadable]. The [Preloader] writes
/// loaded children into [$preloaded] keyed by relation name. Generated
/// typed accessors then expose those values back to user code:
///
/// ```dart
/// final users = await Query<User>().preload([User.posts]).all(db);
/// for (final u in users) {
///   for (final p in u.posts) {  // typed accessor reads $preloaded
///     print(p.title);
///   }
/// }
/// ```
///
/// The `$` prefix on the storage map is intentional: it signals that
/// the field is for runtime/codegen use and should not be touched by
/// user code.
library gisila.runtime.preloadable;

mixin Preloadable {
  /// Internal storage written by the preloader. Keys are the relation
  /// names defined on the parent model (e.g. `'posts'`).
  final Map<String, Object?> $preloaded = {};

  /// Read-typed access. Returns `null` if the relation has not been
  /// preloaded for this instance.
  T? preloaded<T>(String relationName) => $preloaded[relationName] as T?;

  /// True if [relationName] has any value (including an empty list)
  /// stored on this instance.
  bool isPreloaded(String relationName) => $preloaded.containsKey(relationName);
}
