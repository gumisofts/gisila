/// `source_gen` Generator that turns each `@Controller` class into an
/// extension method `attachToApp(GisilaApp app, Router router,
/// {String prefix = ''})` that registers every annotated route via
/// the new `gisilaRoute(...)` runtime helper.
///
/// Each generated registration:
///
/// * builds the effective [RouteConfig] by merging
///   `AppConfig.defaultRouteConfig` ← `@UseRouteConfig` class config
///   ← annotation-derived guards (`@RequireAuth`, `@Permissions`, …)
///   ← method-level `config:` ← named middleware list (`@UseMiddleware`),
/// * binds path / query / header / body / [Form] / [Service] /
///   [RequestContext] / `Request` parameters from the request,
/// * calls the user method and converts the return value to a
///   [Response] (or returns it as-is when the method already returns
///   one).
///
/// Crucially, the generated handler **does not** contain inline
/// `guardRequest(...)` calls anymore; AuthN/AuthZ is moved into a
/// per-route middleware that `gisilaRoute` composes for us.
library gisila.builder.controller_generator;

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import '../annotations/controller.dart';
import 'route_config_literal.dart';
import 'utils.dart';

/// Where a method parameter is sourced from.
enum _Source {
  path,
  query,
  header,
  body,
  request,
  context,
  form,
  service,
  none,
}

class ControllerGenerator extends GeneratorForAnnotation<Controller> {
  const ControllerGenerator();

  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        '@Controller must be placed on a class.',
        element: element,
      );
    }

    final cls = element;
    final controllerPrefix = annotation.read('path').stringValue;
    final classGuards = _readGuards(cls.metadata);
    final classMiddleware = _readMiddlewareNames(cls.metadata);
    final classRouteConfig = _readUseRouteConfig(cls.metadata);

    final routeBlocks = <String>[];
    for (final method in cls.methods) {
      final route = _readRoute(method);
      if (route == null) continue;
      routeBlocks.add(_emitRoute(
        cls: cls,
        method: method,
        route: route,
        controllerPrefix: controllerPrefix,
        classGuards: classGuards,
        classMiddleware: classMiddleware,
        classRouteConfig: classRouteConfig,
      ));
    }

    if (routeBlocks.isEmpty) {
      log.warning(
        'gisila: ${cls.name} is annotated with @Controller but has '
        'no methods carrying @Get/@Post/... ; skipping.',
      );
      return '';
    }

    final buffer = StringBuffer()
      ..writeln('// **************************************************')
      ..writeln('// gisila: generated for ${cls.name}')
      ..writeln('// **************************************************')
      ..writeln()
      ..writeln('extension ${cls.name}GisilaWeb on ${cls.name} {')
      ..writeln('  /// Registers every annotated route of this controller on')
      ..writeln('  /// [router] using [app] for service resolution, named')
      ..writeln('  /// middleware lookup, authentication, permission checks,')
      ..writeln('  /// per-route configuration and error handling.')
      ..writeln('  ///')
      ..writeln('  /// Pass [prefix] to mount the controller under an extra')
      ..writeln('  /// path segment (e.g. an `/api/v1` versioning prefix).')
      ..writeln('  void attachToApp(')
      ..writeln('    GisilaApp app,')
      ..writeln('    Router router, {')
      ..writeln('    String prefix = \'\',')
      ..writeln('  }) {')
      ..writeln(routeBlocks.join('\n'))
      ..writeln('  }')
      ..writeln('}');

    return buffer.toString();
  }

  // -------------------------------------------------------------------------
  // Per-route codegen
  // -------------------------------------------------------------------------

  String _emitRoute({
    required ClassElement cls,
    required MethodElement method,
    required _RouteMeta route,
    required String controllerPrefix,
    required _Guards classGuards,
    required List<String> classMiddleware,
    required DartObject? classRouteConfig,
  }) {
    final fullPath = joinPath(controllerPrefix, route.path);
    final shelfPath = toShelfPath(fullPath);
    final placeholders = pathPlaceholders(fullPath).toSet();

    final methodGuards = _readGuards(method.metadata);
    final methodMiddleware = _readMiddlewareNames(method.metadata);

    final effectiveGuards = methodGuards.isPublic
        ? const _Guards.public()
        : _mergeGuards(classGuards, methodGuards);

    final paramInfos = _classifyParameters(
      method: method,
      placeholders: placeholders,
    );

    final wantsContext = paramInfos.any((p) => p.source == _Source.context);
    final wantsRequest = paramInfos.any((p) => p.source == _Source.request);

    final argExprs = <String>[];
    final namedArgExprs = <String>[];
    final extractStatements = <String>[];

    for (final pi in paramInfos) {
      switch (pi.source) {
        case _Source.request:
          _appendArgWith(argExprs, namedArgExprs, pi, 'request');
          break;

        case _Source.context:
          _appendArgWith(argExprs, namedArgExprs, pi, 'ctx');
          break;

        case _Source.form:
          final typeName = typeDisplayName(pi.parameter.type);
          extractStatements.add(
            'final ${pi.parameter.name} = '
            'await bindForm(request, $typeName.new);',
          );
          _appendArg(argExprs, namedArgExprs, pi);
          break;

        case _Source.service:
          final typeName = typeDisplayName(pi.parameter.type);
          extractStatements.add(
            'final ${pi.parameter.name} = ctx.service<$typeName>();',
          );
          _appendArg(argExprs, namedArgExprs, pi);
          break;

        case _Source.path:
          final typeName = typeDisplayNameNullable(pi.parameter.type);
          extractStatements.add(
            'final ${pi.parameter.name} = coerce<$typeName>('
            'request.params[${dartString(pi.apiName)}], '
            '${dartString(pi.apiName)}, required: true);',
          );
          _appendArg(argExprs, namedArgExprs, pi);
          break;

        case _Source.query:
          final typeName = typeDisplayNameNullable(pi.parameter.type);
          final required =
              !pi.parameter.isOptional && !isNullable(pi.parameter.type);
          extractStatements.add(
            'final ${pi.parameter.name} = coerce<$typeName>('
            'request.url.queryParameters[${dartString(pi.apiName)}], '
            '${dartString(pi.apiName)}, required: $required);',
          );
          _appendArg(argExprs, namedArgExprs, pi);
          break;

        case _Source.header:
          extractStatements.add(
            'final ${pi.parameter.name} = '
            'request.headers[${dartString(pi.apiName.toLowerCase())}];',
          );
          _appendArg(argExprs, namedArgExprs, pi);
          break;

        case _Source.body:
          final required =
              !pi.parameter.isOptional && !isNullable(pi.parameter.type);
          extractStatements.addAll(_emitBodyExtraction(pi, required: required));
          _appendArg(argExprs, namedArgExprs, pi);
          break;

        case _Source.none:
          throw InvalidGenerationSourceError(
            'gisila: could not classify parameter "${pi.parameter.name}" '
            'of ${cls.name}.${method.name}. Annotate it with @Path, @Query, '
            '@Header or @Body, declare it as a Form / Service subtype, '
            'or remove it.',
            element: pi.parameter,
          );
      }
    }

    // ---------- call & response handling ----------
    final returnType = unwrapFuture(method.returnType);
    final returnsResponse = isShelfResponse(returnType);
    final returnsVoid = isVoid(method.returnType);

    final callArgs = StringBuffer('this.${method.name}(')
      ..write(argExprs.join(', '));
    if (namedArgExprs.isNotEmpty) {
      if (argExprs.isNotEmpty) callArgs.write(', ');
      callArgs.write(namedArgExprs.join(', '));
    }
    callArgs.write(')');

    final extractBlock = extractStatements.isEmpty
        ? ''
        : '${extractStatements.join('\n          ')}\n          ';

    final successStatus = route.successStatus;

    String returnStmt;
    if (returnsResponse) {
      returnStmt = '''final response = await $callArgs;
          return response;''';
    } else if (returnsVoid) {
      returnStmt = '''await $callArgs;
          return emptyResponse(statusCode: $successStatus);''';
    } else {
      returnStmt = '''final result = await $callArgs;
          return jsonResponse(body: result, statusCode: $successStatus);''';
    }

    // Only materialise the `request` alias when extraction statements
    // (or the controller itself via _Source.request) actually refer
    // to it. The handler closure already receives `ctx`.
    final requestRefRe = RegExp(r'\brequest\b');
    final needsRequest =
        wantsRequest || extractStatements.any((s) => requestRefRe.hasMatch(s));
    final requestAlias =
        needsRequest ? 'final request = ctx.request;\n          ' : '';
    // Suppress unused-warning lint emission when the controller does
    // not declare a `ctx` parameter and no extract block touches it.
    if (wantsContext) {/* ctx is consumed by the user method */}

    // ---------- route config literal ----------
    final classConfigLiteral = emitRouteConfigLiteral(classRouteConfig);
    final guardsConfigLiteral = emitGuardsRouteConfigLiteral(
      requireAuth: effectiveGuards.requireAuth,
      permissions: effectiveGuards.permissions,
      anyPermission: effectiveGuards.anyPermission,
      roles: effectiveGuards.roles,
      isPublic: effectiveGuards.isPublic,
    );
    final methodConfigLiteral = emitRouteConfigLiteral(route.config);

    final mergedNamedMw = <String>{...classMiddleware, ...methodMiddleware};
    final namedMwConfigLiteral = emitNamedMiddlewareConfig(mergedNamedMw);

    final mergeChain = StringBuffer(classConfigLiteral);
    if (guardsConfigLiteral != 'RouteConfig.empty') {
      mergeChain.write('.merge($guardsConfigLiteral)');
    }
    if (methodConfigLiteral != 'RouteConfig.empty') {
      mergeChain.write('.merge($methodConfigLiteral)');
    }
    if (namedMwConfigLiteral != null) {
      mergeChain.write('.merge($namedMwConfigLiteral)');
    }

    final cfgExpr = mergeChain.toString();

    return '''
    {
      final basePath = '\$prefix$shelfPath';
      final RouteConfig __cfg = $cfgExpr;
      router.${route.method.toLowerCase()}(basePath, gisilaRoute(
        app: app,
        config: __cfg,
        handler: (RequestContext ctx) async {
          try {
            $requestAlias$extractBlock$returnStmt
          } on TypeError catch (e) {
            throw BadRequestException('Invalid request payload (\$e)');
          } on FormatException catch (e) {
            throw BadRequestException('Invalid request format: \${e.message}');
          }
        },
      ));
    }''';
  }

  void _appendArg(
    List<String> positional,
    List<String> named,
    _ParamInfo pi,
  ) {
    _appendArgWith(positional, named, pi, pi.parameter.name);
  }

  void _appendArgWith(
    List<String> positional,
    List<String> named,
    _ParamInfo pi,
    String value,
  ) {
    if (pi.parameter.isNamed) {
      named.add('${pi.parameter.name}: $value');
    } else {
      positional.add(value);
    }
  }

  // -------------------------------------------------------------------------
  // Annotation reading
  // -------------------------------------------------------------------------

  _RouteMeta? _readRoute(MethodElement method) {
    String? httpMethod;
    String? path;
    int successStatus = 200;
    DartObject? config;
    for (final m in method.metadata) {
      final value = m.computeConstantValue();
      if (value == null) continue;
      final type = value.type;
      final element = type?.element;
      if (element is! ClassElement) continue;
      if (!_isRouteSubtype(element)) continue;
      final r = ConstantReader(value);
      httpMethod = r.peek('method')?.stringValue;
      path = r.peek('path')?.stringValue;
      successStatus = r.peek('statusCode')?.intValue ?? 200;
      final cfg = r.peek('config');
      if (cfg != null && !cfg.isNull) {
        config = cfg.objectValue;
      }
      break;
    }
    if (httpMethod == null || path == null) return null;
    return _RouteMeta(
      method: httpMethod,
      path: path,
      successStatus: successStatus,
      config: config,
    );
  }

  bool _isRouteSubtype(ClassElement element) {
    ClassElement? c = element;
    while (c != null) {
      if (c.name == 'Route' && c.library.identifier.contains('gisila')) {
        return true;
      }
      final superType = c.supertype;
      if (superType == null) break;
      final superElement = superType.element;
      c = superElement is ClassElement ? superElement : null;
    }
    return false;
  }

  /// Reads the (optional) class-level `@UseRouteConfig(config)`.
  DartObject? _readUseRouteConfig(List<ElementAnnotation> metadata) {
    for (final m in metadata) {
      final value = m.computeConstantValue();
      if (value == null) continue;
      final type = value.type;
      final element = type?.element;
      if (element is! ClassElement) continue;
      if (element.name != 'UseRouteConfig') continue;
      if (!element.library.identifier.contains('gisila')) continue;
      final cfg = value.getField('config');
      if (cfg != null && !cfg.isNull) return cfg;
    }
    return null;
  }

  _Guards _readGuards(List<ElementAnnotation> metadata) {
    var requireAuth = false;
    final perms = <String>{};
    final anyPerm = <String>{};
    final roles = <String>{};
    var isPublic = false;

    for (final m in metadata) {
      final value = m.computeConstantValue();
      if (value == null) continue;
      final type = value.type;
      final element = type?.element;
      if (element is! ClassElement) continue;
      if (!element.library.identifier.contains('gisila')) continue;

      switch (element.name) {
        case 'RequireAuth':
          requireAuth = true;
          break;
        case 'Public':
          isPublic = true;
          break;
        case 'Permissions':
          requireAuth = true;
          perms.addAll(_readStringSet(value, 'values'));
          break;
        case 'AnyPermission':
          requireAuth = true;
          anyPerm.addAll(_readStringSet(value, 'values'));
          break;
        case 'Roles':
          requireAuth = true;
          roles.addAll(_readStringSet(value, 'values'));
          break;
      }
    }

    return _Guards(
      requireAuth: requireAuth,
      permissions: perms,
      anyPermission: anyPerm,
      roles: roles,
      isPublic: isPublic,
    );
  }

  Set<String> _readStringSet(DartObject value, String field) {
    final v = value.getField(field);
    if (v == null) return const <String>{};
    final set = v.toSetValue();
    if (set != null) {
      return set.map((d) => d.toStringValue()).whereType<String>().toSet();
    }
    final list = v.toListValue();
    if (list != null) {
      return list.map((d) => d.toStringValue()).whereType<String>().toSet();
    }
    return const <String>{};
  }

  List<String> _readMiddlewareNames(List<ElementAnnotation> metadata) {
    final names = <String>[];
    for (final m in metadata) {
      final value = m.computeConstantValue();
      if (value == null) continue;
      final type = value.type;
      final element = type?.element;
      if (element is! ClassElement) continue;
      if (element.name != 'UseMiddleware') continue;
      if (!element.library.identifier.contains('gisila')) continue;
      final name = value.getField('name')?.toStringValue();
      if (name != null && name.isNotEmpty) names.add(name);
    }
    return names;
  }

  _Guards _mergeGuards(_Guards a, _Guards b) {
    return _Guards(
      requireAuth: a.requireAuth || b.requireAuth,
      permissions: {...a.permissions, ...b.permissions},
      anyPermission: {...a.anyPermission, ...b.anyPermission},
      roles: {...a.roles, ...b.roles},
      isPublic: false,
    );
  }

  // -------------------------------------------------------------------------
  // Parameter classification
  // -------------------------------------------------------------------------

  List<_ParamInfo> _classifyParameters({
    required MethodElement method,
    required Set<String> placeholders,
  }) {
    final infos = <_ParamInfo>[];
    var bodySeen = false;
    for (final p in method.parameters) {
      final annot = _findParamAnnotation(p);
      if (annot != null) {
        infos.add(_ParamInfo(
          parameter: p,
          source: annot.source,
          apiName: annot.name ?? p.name,
        ));
        if (annot.source == _Source.body) bodySeen = true;
        continue;
      }

      if (isShelfRequest(p.type)) {
        infos.add(
            _ParamInfo(parameter: p, source: _Source.request, apiName: p.name));
        continue;
      }

      if (isRequestContext(p.type)) {
        infos.add(
            _ParamInfo(parameter: p, source: _Source.context, apiName: p.name));
        continue;
      }

      if (isFormSubtype(p.type)) {
        infos.add(
            _ParamInfo(parameter: p, source: _Source.form, apiName: p.name));
        continue;
      }

      if (isServiceSubtype(p.type)) {
        infos.add(
            _ParamInfo(parameter: p, source: _Source.service, apiName: p.name));
        continue;
      }

      if (placeholders.contains(p.name)) {
        infos.add(
            _ParamInfo(parameter: p, source: _Source.path, apiName: p.name));
        continue;
      }

      if (isCoercible(p.type)) {
        infos.add(
            _ParamInfo(parameter: p, source: _Source.query, apiName: p.name));
        continue;
      }

      if (!bodySeen) {
        infos.add(
            _ParamInfo(parameter: p, source: _Source.body, apiName: p.name));
        bodySeen = true;
        continue;
      }

      infos
          .add(_ParamInfo(parameter: p, source: _Source.none, apiName: p.name));
    }
    return infos;
  }

  _ParamAnnotation? _findParamAnnotation(ParameterElement p) {
    for (final m in p.metadata) {
      final value = m.computeConstantValue();
      if (value == null) continue;
      final type = value.type;
      final element = type?.element;
      if (element is! ClassElement) continue;
      if (!element.library.identifier.contains('gisila')) continue;
      switch (element.name) {
        case 'Path':
          return _ParamAnnotation(
            source: _Source.path,
            name: value.getField('name')?.toStringValue(),
          );
        case 'Query':
          return _ParamAnnotation(
            source: _Source.query,
            name: value.getField('name')?.toStringValue(),
          );
        case 'Header':
          return _ParamAnnotation(
            source: _Source.header,
            name: value.getField('name')?.toStringValue(),
          );
        case 'Body':
          return _ParamAnnotation(source: _Source.body, name: null);
      }
    }
    return null;
  }

  // -------------------------------------------------------------------------
  // Body decoding
  // -------------------------------------------------------------------------

  /// Emits the statements that materialise the body parameter [pi].
  ///
  /// Dispatch is by **parameter type**:
  ///
  /// * `FormData`        → `readFormBody` (multipart / urlencoded only)
  /// * `UploadedFile`    → `readFormBody` + look up by parameter name
  /// * custom class with `fromForm` factory → `readBody` + `fromForm`
  /// * custom class with `fromJson` factory → `readBody` + `fromJson`
  /// * `Map<String, dynamic>` / `Map`        → `readBody` + cast
  /// * `List<T>` (with or without `fromJson`) → `readJsonBody`
  /// * anything else                          → `readBody` (raw)
  ///
  /// `readBody` dispatches by `Content-Type` internally, so the same
  /// generated handler accepts JSON, form-urlencoded, and (for
  /// `Map`/custom classes) multipart bodies without any extra wiring.
  List<String> _emitBodyExtraction(
    _ParamInfo pi, {
    required bool required,
  }) {
    final type = pi.parameter.type;
    final name = pi.parameter.name;
    final apiName = pi.apiName;

    // ---- FormData -------------------------------------------------------
    if (isFormData(type)) {
      final reader = 'await readFormBody(request, required: $required)';
      if (required) {
        return <String>[
          'final $name = ($reader)!;',
        ];
      }
      return <String>[
        'final $name = $reader;',
      ];
    }

    // ---- UploadedFile (single file by name) -----------------------------
    if (isUploadedFile(type)) {
      // Use the parameter's API name (override-able via @Body or
      // implicitly via the parameter name) as the form field key.
      final fieldKey = dartString(apiName);
      return <String>[
        'final __form_$name = '
            'await readFormBody(request, required: $required);',
        if (required)
          'final $name = __form_$name!.files[$fieldKey] ?? '
              "(throw BadRequestException('Missing file \"$apiName\" in multipart body.'));"
        else
          'final $name = __form_$name?.files[$fieldKey];',
      ];
    }

    // ---- List<T> (only meaningful for JSON arrays) ----------------------
    final inner = listElementType(type);
    if (inner != null) {
      final readerCall = 'await readJsonBody(request, required: $required)';
      if (inner is InterfaceType) {
        final innerElement = inner.element;
        if (innerElement is ClassElement &&
            fromJsonConstructor(innerElement) != null) {
          final n = innerElement.name;
          return <String>[
            'final __raw_$name = $readerCall;',
            if (required)
              'final $name = (__raw_$name as List)'
                  '.map((e) => $n.fromJson(e as Map<String, dynamic>))'
                  '.toList();'
            else
              'final $name = (__raw_$name as List?)'
                  '?.map((e) => $n.fromJson(e as Map<String, dynamic>))'
                  '.toList();',
          ];
        }
      }
      return <String>[
        'final __raw_$name = $readerCall;',
        if (required)
          'final $name = (__raw_$name as List);'
        else
          'final $name = (__raw_$name as List?);',
      ];
    }

    // ---- Custom class with fromForm / fromJson -------------------------
    if (type is InterfaceType) {
      final element = type.element;
      if (element is ClassElement) {
        final hasFromForm = fromFormConstructor(element) != null;
        final hasFromJson = fromJsonConstructor(element) != null;
        if (hasFromForm || hasFromJson) {
          final n = element.name;
          // When both factories exist, dispatch at runtime: FormData
          // (i.e. multipart / urlencoded) gets fromForm so the user
          // can coerce string-only values; everything else gets
          // fromJson with native JSON types.
          final String buildExpr;
          if (hasFromForm && hasFromJson) {
            buildExpr = '__raw_$name is FormData '
                '? $n.fromForm((__raw_$name as Map).cast<String, dynamic>()) '
                ': $n.fromJson((__raw_$name as Map).cast<String, dynamic>())';
          } else if (hasFromForm) {
            buildExpr =
                '$n.fromForm((__raw_$name as Map).cast<String, dynamic>())';
          } else {
            buildExpr =
                '$n.fromJson((__raw_$name as Map).cast<String, dynamic>())';
          }
          return <String>[
            'final __raw_$name = '
                'await readBody(request, required: $required);',
            if (required)
              'final $name = $buildExpr;'
            else
              'final $name = __raw_$name == null ? null : ($buildExpr);',
          ];
        }
      }
      // Plain Map / Map<String, dynamic>.
      if (isStringMap(type) || type.isDartCoreMap) {
        return <String>[
          'final __raw_$name = '
              'await readBody(request, required: $required);',
          if (required)
            'final $name = (__raw_$name as Map).cast<String, dynamic>();'
          else
            'final $name = (__raw_$name as Map?)?.cast<String, dynamic>();',
        ];
      }
    }

    // ---- Fallback: raw decoded body ------------------------------------
    return <String>[
      'final $name = await readBody(request, required: $required);',
    ];
  }
}

class _RouteMeta {
  _RouteMeta({
    required this.method,
    required this.path,
    required this.successStatus,
    this.config,
  });
  final String method;
  final String path;
  final int successStatus;
  final DartObject? config;
}

class _ParamInfo {
  _ParamInfo({
    required this.parameter,
    required this.source,
    required this.apiName,
  });
  final ParameterElement parameter;
  final _Source source;
  final String apiName;
}

class _ParamAnnotation {
  _ParamAnnotation({required this.source, this.name});
  final _Source source;
  final String? name;
}

class _Guards {
  const _Guards({
    required this.requireAuth,
    required this.permissions,
    required this.anyPermission,
    required this.roles,
    required this.isPublic,
  });

  const _Guards.public()
      : requireAuth = false,
        permissions = const <String>{},
        anyPermission = const <String>{},
        roles = const <String>{},
        isPublic = true;

  final bool requireAuth;
  final Set<String> permissions;
  final Set<String> anyPermission;
  final Set<String> roles;
  final bool isPublic;
}
