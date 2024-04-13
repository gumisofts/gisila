import 'package:build/build.dart';
import 'package:project_mega/models/generators/fromyaml.dart';
import 'package:project_mega/models/generators/generator.dart';
import 'package:source_gen/source_gen.dart';

Builder modelPartBuilder(BuilderOptions options) =>
    SharedPartBuilder([ModelFromJsonAnnotation()], 'models');
Builder modelFromYamlBuilder(BuilderOptions options) => ModelFromYamlBuilder();
