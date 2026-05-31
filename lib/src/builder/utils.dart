/// Small analyzer / string helpers shared by the build-time code.
library gisila.builder.utils;

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

/// True iff [type] is `T?` (or `Null`).
bool isNullable(DartType type) =>
    type.nullabilitySuffix == NullabilitySuffix.question || type.isDartCoreNull;

/// Display string with explicit nullability suffix preserved.
String typeDisplayNameNullable(DartType type) => type.getDisplayString();

/// Display string with the nullability suffix stripped.
String typeDisplayName(DartType type) {
  final full = type.getDisplayString();
  return full.endsWith('?') ? full.substring(0, full.length - 1) : full;
}

/// Standard primitives we can parse from a path / query / header string.
bool isCoercible(DartType type) {
  final name = typeDisplayName(type);
  return const {
    'String',
    'int',
    'double',
    'num',
    'bool',
    'DateTime',
  }.contains(name);
}

bool isShelfRequest(DartType type) {
  final element = type.element;
  if (element is! ClassElement) return false;
  return element.name == 'Request' &&
      element.library.identifier.startsWith('package:shelf/');
}

bool isShelfResponse(DartType type) {
  final element = type.element;
  if (element is! ClassElement) return false;
  return element.name == 'Response' &&
      element.library.identifier.startsWith('package:shelf/');
}

/// True iff [type] is `RequestContext` from `package:gisila`.
bool isRequestContext(DartType type) {
  final element = type.element;
  if (element is! ClassElement) return false;
  return element.name == 'RequestContext' &&
      element.library.identifier.startsWith('package:gisila/');
}

/// True iff [type] is `FormData` from `package:gisila`.
bool isFormData(DartType type) {
  final element = type.element;
  if (element is! ClassElement) return false;
  return element.name == 'FormData' &&
      element.library.identifier.startsWith('package:gisila/');
}

/// True iff [type] is `UploadedFile` from `package:gisila`.
bool isUploadedFile(DartType type) {
  final element = type.element;
  if (element is! ClassElement) return false;
  return element.name == 'UploadedFile' &&
      element.library.identifier.startsWith('package:gisila/');
}

bool _isSubtypeOf(DartType type, String className) {
  final element = type.element;
  if (element is! ClassElement) return false;
  ClassElement? cursor = element;
  while (cursor != null) {
    if (cursor.name == className &&
        cursor.library.identifier.startsWith('package:gisila/')) {
      return true;
    }
    final superType = cursor.supertype;
    if (superType == null) break;
    final superElement = superType.element;
    cursor = superElement is ClassElement ? superElement : null;
  }
  return false;
}

/// True iff [type] is (a subclass of) the gisila `Form` class.
bool isFormSubtype(DartType type) => _isSubtypeOf(type, 'Form');

/// True iff [type] is (a subclass of) the gisila `Service` class.
bool isServiceSubtype(DartType type) => _isSubtypeOf(type, 'Service');

DartType unwrapFuture(DartType type) {
  if (type is InterfaceType &&
      type.element.name == 'Future' &&
      type.element.library.isDartAsync) {
    if (type.typeArguments.isNotEmpty) return type.typeArguments.first;
  }
  return type;
}

bool isVoid(DartType type) => unwrapFuture(type) is VoidType;

bool isStringMap(DartType type) {
  if (type is! InterfaceType || !type.isDartCoreMap) return false;
  if (type.typeArguments.length != 2) return false;
  return typeDisplayName(type.typeArguments[0]) == 'String';
}

DartType? listElementType(DartType type) {
  if (type is InterfaceType &&
      type.isDartCoreList &&
      type.typeArguments.isNotEmpty) {
    return type.typeArguments.first;
  }
  return null;
}

Iterable<String> pathPlaceholders(String path) sync* {
  final re = RegExp(r'\{([a-zA-Z_][a-zA-Z0-9_]*)\}');
  for (final m in re.allMatches(path)) {
    yield m.group(1)!;
  }
}

/// Converts an OpenAPI-style path like `/users/{id}` to the
/// shelf_router-style path `/users/<id>`.
String toShelfPath(String path) {
  return path.replaceAllMapped(
    RegExp(r'\{([a-zA-Z_][a-zA-Z0-9_]*)\}'),
    (m) => '<${m.group(1)}>',
  );
}

ConstructorElement? fromJsonConstructor(ClassElement cls) {
  for (final c in cls.constructors) {
    if (c.name != 'fromJson') continue;
    if (c.parameters.length != 1) continue;
    final t = c.parameters.first.type;
    if (t is InterfaceType && t.isDartCoreMap) return c;
  }
  return null;
}

/// Returns the `fromForm(Map<String, dynamic>)` factory if [cls]
/// exposes one. Used to decode form-urlencoded / multipart request
/// bodies, with priority over [fromJsonConstructor] when both exist.
ConstructorElement? fromFormConstructor(ClassElement cls) {
  for (final c in cls.constructors) {
    if (c.name != 'fromForm') continue;
    if (c.parameters.length != 1) continue;
    final t = c.parameters.first.type;
    if (t is InterfaceType && t.isDartCoreMap) return c;
  }
  return null;
}

/// Quotes [value] as a Dart single-quoted string literal.
String dartString(String value) {
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll(r"'", r"\'")
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r')
      .replaceAll('\$', r'\$');
  return "'$escaped'";
}

/// Joins a controller prefix with a method-level path, collapsing
/// trailing/leading slashes.
String joinPath(String prefix, String suffix) {
  final p =
      prefix.endsWith('/') ? prefix.substring(0, prefix.length - 1) : prefix;
  final s = suffix.startsWith('/') ? suffix : '/$suffix';
  final out = '$p$s';
  return out.isEmpty ? '/' : out;
}

/// Renders a Dart `<String>{...}` literal (or `<String>{}` for empty).
String stringSetLiteral(Iterable<String> values) {
  final list = values.toList(growable: false);
  if (list.isEmpty) return 'const <String>{}';
  return 'const <String>{${list.map(dartString).join(', ')}}';
}
