/// Parameter annotations.
///
/// In most cases these are not needed: the generator infers the
/// parameter source from its position, type and name. Use them only to
/// override naming or mark a body as optional.
library gisila.annotations.params;

import 'package:meta/meta_meta.dart';

/// Marks a method parameter as the request body. The body is decoded
/// as JSON and either passed as a `Map<String, dynamic>` or, if the
/// parameter type has a `fromJson` factory constructor, hydrated
/// through that.
@Target({TargetKind.parameter})
class Body {
  const Body({
    this.contentType = 'application/json',
    this.required = true,
  });
  final String contentType;
  final bool required;
}

/// Marks a method parameter as a query-string parameter. By default
/// the parameter name is used as the query key; pass [name] to
/// override.
@Target({TargetKind.parameter})
class Query {
  const Query({this.name});
  final String? name;
}

/// Marks a method parameter as a path parameter. Inferred
/// automatically when the parameter name matches a `{placeholder}`
/// segment in the route path; use this to override naming.
@Target({TargetKind.parameter})
class Path {
  const Path({this.name});
  final String? name;
}

/// Marks a method parameter as an HTTP header.
@Target({TargetKind.parameter})
class Header {
  const Header({this.name});
  final String? name;
}
