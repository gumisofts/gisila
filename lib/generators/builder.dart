import 'package:build/build.dart';
import 'package:d_orm/generators/fromyaml.dart';
import 'package:d_orm/generators/generator.dart';
import 'package:source_gen/source_gen.dart';

Builder modelPartBuilder(BuilderOptions options) =>
    SharedPartBuilder([ModelFromJsonAnnotation()], 'models');
Builder modelFromYamlBuilder(BuilderOptions options) => ModelFromYamlBuilder();
