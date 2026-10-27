/// Helpers that turn a `RouteConfig` (or its sub-objects) parsed from
/// an annotation into a Dart source literal the generator can paste
/// straight into the generated file.
///
/// The literal emitter only handles the subset of types that can
/// appear inside a `const RouteConfig(...)`:
///
/// * [RouteConfig], [RateLimitConfig], [CorsConfig], [Duration]
/// * function tear-offs (`RateLimitConfig.keyExtractor`)
/// * primitives (`int`, `bool`, `String`) and `Set<String>`
/// * `null`
///
/// `middleware: const <Middleware>[]` is the only acceptable value
/// for the [RouteConfig.middleware] field because `Middleware`
/// (typedef of `Handler Function(Handler)`) cannot be `const`.
library gisila.builder.route_config_literal;

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';

import 'utils.dart' show dartString, stringSetLiteral;

/// Emits a Dart source literal that reconstructs the const
/// [RouteConfig] represented by [obj]. Returns `'RouteConfig.empty'`
/// if [obj] is `null`.
String emitRouteConfigLiteral(DartObject? obj) {
  if (obj == null) return 'RouteConfig.empty';
  final rateLimit = _emitRateLimitLiteral(obj.getField('rateLimit'));
  final timeout = _emitDurationLiteral(obj.getField('timeout'));
  final maxBodyBytes = obj.getField('maxBodyBytes')?.toIntValue();
  final contentTypes = _stringSetOrNull(obj.getField('contentTypes'));
  final cors = _emitCorsConfigLiteral(obj.getField('cors'));
  final requireAuth = obj.getField('requireAuth')?.toBoolValue() ?? false;
  final permissions = _stringSet(obj.getField('permissions'));
  final anyPermission = _stringSet(obj.getField('anyPermission'));
  final roles = _stringSet(obj.getField('roles'));
  final statusCode = obj.getField('statusCode')?.toIntValue();
  final isPublic = obj.getField('isPublic')?.toBoolValue() ?? false;

  final args = <String>[];
  if (rateLimit != null) args.add('rateLimit: $rateLimit');
  if (timeout != null) args.add('timeout: $timeout');
  if (maxBodyBytes != null) args.add('maxBodyBytes: $maxBodyBytes');
  if (contentTypes != null) args.add('contentTypes: $contentTypes');
  if (cors != null) args.add('cors: $cors');
  if (requireAuth) args.add('requireAuth: true');
  if (permissions.isNotEmpty) {
    args.add('permissions: ${stringSetLiteral(permissions)}');
  }
  if (anyPermission.isNotEmpty) {
    args.add('anyPermission: ${stringSetLiteral(anyPermission)}');
  }
  if (roles.isNotEmpty) args.add('roles: ${stringSetLiteral(roles)}');
  if (statusCode != null) args.add('statusCode: $statusCode');
  if (isPublic) args.add('isPublic: true');

  if (args.isEmpty) return 'RouteConfig.empty';
  return 'const RouteConfig(${args.join(', ')})';
}

/// Synthesises a `RouteConfig` literal that carries auth / permission
/// guards collected from `@RequireAuth` / `@Permissions` /
/// `@AnyPermission` / `@Roles` / `@Public` annotations.
String emitGuardsRouteConfigLiteral({
  required bool requireAuth,
  required Set<String> permissions,
  required Set<String> anyPermission,
  required Set<String> roles,
  required bool isPublic,
}) {
  if (!requireAuth &&
      permissions.isEmpty &&
      anyPermission.isEmpty &&
      roles.isEmpty &&
      !isPublic) {
    return 'RouteConfig.empty';
  }
  final args = <String>[];
  if (isPublic) args.add('isPublic: true');
  if (requireAuth) args.add('requireAuth: true');
  if (permissions.isNotEmpty) {
    args.add('permissions: ${stringSetLiteral(permissions)}');
  }
  if (anyPermission.isNotEmpty) {
    args.add('anyPermission: ${stringSetLiteral(anyPermission)}');
  }
  if (roles.isNotEmpty) args.add('roles: ${stringSetLiteral(roles)}');
  return 'const RouteConfig(${args.join(', ')})';
}

// ---------------------------------------------------------------------------
// Sub-object literal emitters
// ---------------------------------------------------------------------------

String? _emitRateLimitLiteral(DartObject? obj) {
  if (obj == null || obj.isNull) return null;
  final requestsPerMinute =
      obj.getField('requestsPerMinute')?.toIntValue() ?? 120;
  final burstSize = obj.getField('burstSize')?.toIntValue();
  final trustedProxies = _stringSet(obj.getField('trustedProxies'));
  final maxBuckets = obj.getField('maxBuckets')?.toIntValue();
  final keyExtractor =
      _functionReference(obj.getField('keyExtractor')?.toFunctionValue());
  final args = <String>[
    'requestsPerMinute: $requestsPerMinute',
    if (burstSize != null) 'burstSize: $burstSize',
    if (keyExtractor != null) 'keyExtractor: $keyExtractor',
    if (trustedProxies.isNotEmpty)
      'trustedProxies: ${stringSetLiteral(trustedProxies)}',
    if (maxBuckets != null && maxBuckets != 100000) 'maxBuckets: $maxBuckets',
  ];
  return 'const RateLimitConfig(${args.join(', ')})';
}

/// Source for a const function tear-off: a top-level function by name, a
/// static method as `Class.method`. The generated part shares the
/// controller library's imports, so the name resolves there; a function
/// imported under a prefix needs to be re-exported or wrapped without one.
String? _functionReference(ExecutableElement? fn) {
  if (fn == null) return null;
  final owner = fn.enclosingElement3;
  if (fn is MethodElement && owner is InterfaceElement) {
    return '${owner.name}.${fn.name}';
  }
  return fn.name;
}

String? _emitCorsConfigLiteral(DartObject? obj) {
  if (obj == null || obj.isNull) return null;
  final allowedOrigins = _stringSet(obj.getField('allowedOrigins'));
  final allowedMethods = _stringSet(obj.getField('allowedMethods'));
  final allowedHeaders = _stringSet(obj.getField('allowedHeaders'));
  final exposedHeaders = _stringSet(obj.getField('exposedHeaders'));
  final allowCredentials =
      obj.getField('allowCredentials')?.toBoolValue() ?? false;
  final maxAge = _emitDurationLiteral(obj.getField('maxAge'));

  final args = <String>[
    if (allowedOrigins.isNotEmpty)
      'allowedOrigins: ${stringSetLiteral(allowedOrigins)}',
    if (allowedMethods.isNotEmpty)
      'allowedMethods: ${stringSetLiteral(allowedMethods)}',
    if (allowedHeaders.isNotEmpty)
      'allowedHeaders: ${stringSetLiteral(allowedHeaders)}',
    if (exposedHeaders.isNotEmpty)
      'exposedHeaders: ${stringSetLiteral(exposedHeaders)}',
    if (allowCredentials) 'allowCredentials: true',
    if (maxAge != null) 'maxAge: $maxAge',
  ];
  return 'const CorsConfig(${args.join(', ')})';
}

String? _emitDurationLiteral(DartObject? obj) {
  if (obj == null || obj.isNull) return null;
  // The constant's stored field: `inMicroseconds` in current SDKs, the
  // private `_duration` in older ones. Without either the value would be
  // dropped silently (as `timeout:` was on Dart 3.13).
  final us = (obj.getField('inMicroseconds') ?? obj.getField('_duration'))
      ?.toIntValue();
  if (us != null) {
    return 'const Duration(microseconds: $us)';
  }
  return null;
}

Set<String> _stringSet(DartObject? obj) {
  if (obj == null || obj.isNull) return const <String>{};
  final s = obj.toSetValue();
  if (s != null) {
    return s.map((d) => d.toStringValue()).whereType<String>().toSet();
  }
  final l = obj.toListValue();
  if (l != null) {
    return l.map((d) => d.toStringValue()).whereType<String>().toSet();
  }
  return const <String>{};
}

Set<String>? _stringSetOrNull(DartObject? obj) {
  if (obj == null || obj.isNull) return null;
  return _stringSet(obj);
}

/// Renders a list of class-and-method `@UseMiddleware` names into a
/// `RouteConfig` literal that places them in `middleware:` as
/// `app.namedMiddleware(...)` lookups.
///
/// Returns `null` when [names] is empty.
String? emitNamedMiddlewareConfig(Iterable<String> names) {
  final list = names.toList(growable: false);
  if (list.isEmpty) return null;
  final entries = list.map(
    (n) => 'app.namedMiddleware(${dartString(n)})',
  );
  return 'RouteConfig(middleware: <Middleware>[${entries.join(', ')}])';
}
