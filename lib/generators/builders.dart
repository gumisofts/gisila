import 'package:build/build.dart';
import 'package:gisila/generators/generators.dart';
import 'package:gisila/generators/model_generator/generator/generator.dart';
import 'package:source_gen/source_gen.dart';

Builder modelPartBuilder(BuilderOptions options) =>
    SharedPartBuilder([ModelFromJsonAnnotation()], 'models');
Builder modelFromYamlBuilder(BuilderOptions options) => FromYamlGenerator();
