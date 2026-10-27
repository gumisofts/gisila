/// Gisila Web - a small, opinionated Shelf-based web framework.
///
/// Goals:
///
/// * **MVC layout** - thin controllers annotated with [Controller] /
///   [Get] / [Post] / ... that the build_runner generator wires onto a
///   `shelf_router` instance for you.
/// * **Declarative permissions** - guard a whole controller or a single
///   route with [RequireAuth], [Permissions], [AnyPermission] or
///   [Roles]; the framework calls your [Authenticator] /
///   [PermissionResolver] before invoking the handler.
/// * **Pluggable middleware** - register Shelf middleware globally on
///   the [GisilaApp] or per-route via [UseMiddleware].
/// * **Configurable logging** - swap out the [Logger] used for
///   framework and per-request output, choose plain text or JSON, mute
///   request/response bodies, etc. via [AppConfig].
///
/// Quick start:
///
/// ```dart
/// import 'package:gisila/gisila.dart';
///
/// import 'controllers/users_controller.dart';
///
/// Future<void> main() async {
///   final app = GisilaApp(
///     config: AppConfig(
///       logLevel: LogLevel.info,
///       logFormat: LogFormat.text,
///       authenticator: const StaticTokenAuthenticator({
///         'admin-token': Principal(id: 'admin', roles: {'admin'},
///             permissions: {'users:read', 'users:write'}),
///       }),
///     ),
///   );
///
///   // `attachToApp` is generated for every @Controller class.
///   app.registerController(
///     attacher: (app, router, {prefix = ''}) =>
///         UsersController().attachToApp(app, router, prefix: prefix),
///   );
///
///   await app.start(host: '0.0.0.0', port: 8080);
/// }
/// ```
library gisila;

// Re-export the small surface from shelf / shelf_router that the
// generated controller code (and most user code) needs, so a single
// `import 'package:gisila/gisila.dart';` is enough.
export 'package:shelf/shelf.dart'
    show Handler, Middleware, Pipeline, Request, Response;
// Full shelf_router export (minus its `Route` class, which clashes
// with our own [Route] annotation) so generated handlers can rely on
// the `request.params` extension getter.
export 'package:shelf_router/shelf_router.dart' hide Route;

export 'src/annotations/controller.dart';
export 'src/annotations/middleware.dart';
export 'src/annotations/params.dart';
export 'src/annotations/permission.dart';
export 'src/runtime/app.dart';
export 'src/runtime/auth/authenticator.dart';
export 'src/runtime/auth/permission_resolver.dart';
export 'src/runtime/auth/principal.dart';
// Cache layer: pluggable backend (Redis, Memcached, in-memory, …).
export 'src/runtime/cache/cache_middleware.dart' show kCacheKey;
export 'src/runtime/cache/cache_provider.dart';
export 'src/runtime/cache/in_memory_cache_provider.dart';
export 'src/runtime/codec.dart'
    show BadRequestException, coerce, emptyResponse, jsonResponse, readJsonBody;
export 'src/runtime/config.dart';
export 'src/runtime/context.dart';
export 'src/runtime/db/database_provider.dart';
export 'src/runtime/db/db_error_mapper.dart';
export 'src/runtime/db/db_session_middleware.dart' show kDbKey;
export 'src/runtime/exceptions.dart';
export 'src/runtime/logging/log_event.dart';
export 'src/runtime/logging/logger.dart';
export 'src/runtime/middleware/body_limit.dart';
export 'src/runtime/middleware/content_type.dart';
export 'src/runtime/middleware/cors.dart';
export 'src/runtime/middleware/rate_limit.dart';
export 'src/runtime/middleware/request_id.dart';
// Per-route configuration.
export 'src/runtime/route_config.dart';
export 'src/runtime/route_runtime.dart' show GisilaRouteHandler, gisilaRoute;
// Service layer.
export 'src/runtime/service.dart';
// Content-type-aware body parsing.
export 'src/runtime/parsers/body_parser.dart'
    show DecodedBody, readBody, readFormBody;
export 'src/runtime/parsers/form_data.dart'
    show
        FormData,
        UploadedFile,
        defaultMaxFormFieldBytes,
        defaultMaxFormParts,
        formUrlEncodedContentType,
        multipartFormDataContentType,
        parseFormData;
export 'src/runtime/route_guard.dart';
// Typed Form / FormField input validation.
export 'src/runtime/forms.dart'
    show
        BoolField,
        DateTimeField,
        DoubleField,
        EmailField,
        FieldValidator,
        FileField,
        Form,
        FormField,
        FormValidationException,
        IntField,
        JsonField,
        PasswordField,
        StringField,
        bindForm;
