/// build_runner entrypoint for the gisila generator.
///
/// Referenced from `build.yaml`'s `import:` field; consumers never
/// import this file directly.
library gisila.builder;

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/builder/controller_generator.dart';

/// Factory referenced by `build.yaml`.
Builder controllerBuilder(BuilderOptions _) =>
    SharedPartBuilder(const [ControllerGenerator()], 'gisila');
