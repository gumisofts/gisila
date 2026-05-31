/// Per-request [Service] base class.
///
/// Services are the "C → M" hop in the MVC layout: controllers stay
/// thin and forward their inputs to a service, which owns business
/// logic and database access. A fresh [Service] instance is
/// materialised per request by [GisilaApp]; the framework wires
/// [RequestContext] into [ctx] before any service method runs.
///
/// ```dart
/// class AuthService extends Service {
///   Future<User> register(String email, String password) async {
///     final db = ctx.db<Database>();
///     return Query<User>(UserTable.metadata).insert({...}).one(db.context());
///   }
/// }
///
/// // In bootstrap:
/// app.registerService<AuthService>(AuthService.new);
///
/// // In a controller:
/// @Post('/register')
/// Future<User> register(RegisterForm form, AuthService auth) =>
///     auth.register(form.email.value!, form.password.value!);
/// ```
library gisila.runtime.service;

import 'context.dart';

/// Factory signature for services.
///
/// `app.registerService<AuthService>(AuthService.new)` is the typical
/// call site; any zero-arg constructor or factory satisfies the type.
typedef ServiceFactory<S extends Service> = S Function();

/// Per-request service base class.
///
/// Subclasses get the active [RequestContext] (and therefore
/// `ctx.db<T>()`, `ctx.principal`, `ctx.requestId`, …) injected by the
/// framework before any method on the subclass runs.
abstract class Service {
  Service();

  RequestContext? _ctx;

  /// The active request context. Populated by the framework right
  /// after the service is instantiated; throws [StateError] if read
  /// before that happens (which should only ever occur in unit tests
  /// that forget to call [attach]).
  RequestContext get ctx {
    final c = _ctx;
    if (c == null) {
      throw StateError(
        'Service.ctx accessed before the framework attached a '
        'RequestContext. Did you instantiate this Service outside a '
        'gisila request? Call attach(ctx) explicitly in tests.',
      );
    }
    return c;
  }

  /// Convenience: same as `ctx.db<T>()`.
  T db<T>() => ctx.db<T>();

  /// Wires the service to [context]. Used by the framework; tests
  /// call this manually to exercise a service without a full
  /// request pipeline.
  void attach(RequestContext context) {
    _ctx = context;
  }
}
