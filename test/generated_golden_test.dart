/// The generator's output for `fixtures/guarded_controller.dart` must match
/// the checked-in part, which `pipeline_integration_test.dart` runs. When a
/// generator change is intended, regenerate the part (see below) and review
/// the diff.
///
/// To regenerate: `GISILA_UPDATE_GOLDEN=1 dart test
/// test/generated_golden_test.dart`.
library;

import 'dart:io';

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:gisila/builder.dart';
import 'package:test/test.dart';

const _fixture = 'test/fixtures/guarded_controller.dart';
const _part = 'test/fixtures/guarded_controller.g.dart';
const _header = '// GENERATED CODE - DO NOT MODIFY BY HAND\n\n'
    "part of 'guarded_controller.dart';\n\n";

void main() {
  test('generated code for the fixture controller matches the golden part',
      () async {
    final rw = TestReaderWriter(rootPackage: 'gisila');
    await rw.testing.loadIsolateSources();
    late String generated;
    await testBuilder(
      controllerBuilder(BuilderOptions.empty),
      {'gisila|$_fixture': File(_fixture).readAsStringSync()},
      rootPackage: 'gisila',
      readerWriter: rw,
      outputs: {
        'gisila|test/fixtures/guarded_controller.gisila.g.part':
            decodedMatches(predicate<String>((s) {
          generated = s;
          return true;
        })),
      },
    );
    if (Platform.environment['GISILA_UPDATE_GOLDEN'] == '1') {
      File(_part).writeAsStringSync('$_header$generated');
    }
    expect('$_header$generated', File(_part).readAsStringSync());
  }, timeout: const Timeout(Duration(minutes: 3)));
}
