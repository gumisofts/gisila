import 'package:build/build.dart';
import 'package:pg_dorm/generators/fromyaml.dart';
import 'package:pg_dorm/generators/generator.dart';
import 'package:source_gen/source_gen.dart';

Builder modelPartBuilder(BuilderOptions options) =>
    SharedPartBuilder([ModelFromJsonAnnotation()], 'models');
Builder modelFromYamlBuilder(BuilderOptions options) => ModelFromYamlBuilder();
