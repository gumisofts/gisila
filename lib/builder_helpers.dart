/// Build-time helpers re-exposed for other generators that compose
/// with gisila's annotations (notably `gisila_doc`).
///
/// Most application authors do **not** need to import this file;
/// `package:gisila/gisila.dart` covers everything needed at runtime
/// and `package:gisila/builder.dart` exposes the build_runner entry
/// point.
library gisila.builder_helpers;

export 'src/builder/route_config_literal.dart';
export 'src/builder/utils.dart';
