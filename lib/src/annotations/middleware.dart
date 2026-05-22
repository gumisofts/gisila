/// Middleware annotations.
library gisila.annotations.middleware;

import 'package:meta/meta_meta.dart';

/// Attach a Shelf [shelf.Middleware] (referenced by symbol name) to a
/// controller or a single route method.
///
/// The annotation only carries a *symbol* name; the framework looks
/// the middleware up at startup via
/// `GisilaApp.registerNamedMiddleware(name, middleware)`.
///
/// This indirection keeps annotations `const`-constructable while
/// still allowing the host application to supply real, closure-y
/// middleware.
///
/// ```dart
/// app.registerNamedMiddleware('audit', auditMiddleware());
///
/// @UseMiddleware('audit')
/// @Post('/')
/// Future<User> createUser(...) async => ...;
/// ```
@Target({TargetKind.classType, TargetKind.method})
class UseMiddleware {
  const UseMiddleware(this.name);

  /// Name registered on `GisilaApp.registerNamedMiddleware`.
  final String name;
}
