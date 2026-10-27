/// Runs the controller builder on a sample controller and checks the
/// generated handler code.
library;

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:gisila/builder.dart';
import 'package:test/test.dart';

const _source = r'''
import 'package:gisila/gisila.dart';

part 'sample.g.dart';

String byTenant(Request r) => r.headers['x-tenant'] ?? '';

class Keys {
  static String byUser(Request r) => r.headers['x-user'] ?? '';
}

@Controller('/x')
class SampleController {
  @Get('/limited',
      config: RouteConfig(
          rateLimit:
              RateLimitConfig(requestsPerMinute: 5, keyExtractor: byTenant)))
  Future<Map<String, Object?>> limited() async => <String, Object?>{};

  @Get('/limited2',
      config: RouteConfig(
          rateLimit: RateLimitConfig(keyExtractor: Keys.byUser)))
  Future<Map<String, Object?>> limited2() async => <String, Object?>{};

  @Get('/items')
  Future<Map<String, Object?>> items({int? page}) async =>
      <String, Object?>{'page': page};

  @Get('/items/{id}')
  Future<Map<String, Object?>> item(int id, {String? q}) async =>
      <String, Object?>{'id': id};

  @Get('/ping')
  Future<Map<String, Object?>> ping() async => <String, Object?>{};
}
''';

Future<String> _generate() async {
  final rw = TestReaderWriter(rootPackage: 'gisila');
  await rw.testing.loadIsolateSources();
  String? generated;
  await testBuilder(
    controllerBuilder(BuilderOptions.empty),
    {'gisila|lib/sample.dart': _source},
    rootPackage: 'gisila',
    readerWriter: rw,
    outputs: {
      'gisila|lib/sample.gisila.g.part': decodedMatches(predicate<String>((s) {
        generated = s;
        return true;
      })),
    },
  );
  return generated!;
}

/// The handler generated for [path], whitespace removed.
String _handler(String code, String path) {
  final squashed = code.replaceAll(RegExp(r'\s+'), '');
  final at = squashed.indexOf("/x$path';");
  expect(at, isNonNegative, reason: path);
  final next = squashed.indexOf('finalbasePath=', at);
  return squashed.substring(at, next < 0 ? squashed.length : next);
}

void main() {
  late String code;
  setUpAll(() async => code = await _generate());

  group('FW-17 rate-limit key extractors', () {
    test('a top-level function is carried into the route config', () {
      expect(
          _handler(code, '/limited'),
          contains('constRouteConfig(rateLimit:constRateLimitConfig('
              'requestsPerMinute:5,keyExtractor:byTenant))'));
    });

    test('a static method is referenced through its class', () {
      expect(_handler(code, '/limited2'), contains('keyExtractor:Keys.byUser'));
    });
  });

  group('FW-09 only argument binding is wrapped', () {
    test('the controller call is outside the try', () {
      final h = _handler(code, '/items');
      final bindingEnds = h.indexOf('})();');
      expect(h, contains('final(page,)=await(()async{try{'));
      expect(bindingEnds, isPositive);
      expect(h.indexOf('this.items(page:page)'), greaterThan(bindingEnds));
      expect(h.substring(0, bindingEnds), contains('onTypeErrorcatch'));
    });

    test('several bindings come back as one record', () {
      final h = _handler(code, '/items/<id>');
      expect(h, contains('final(id,q)=await(()async{try{'));
      expect(h, contains('return(id,q);'));
      expect(h.indexOf('this.item(id,q:q)'), greaterThan(h.indexOf('})();')));
    });

    test('a route without parameters has no try at all', () {
      final h = _handler(code, '/ping');
      expect(h, isNot(contains('try{')));
      expect(h, contains('this.ping()'));
    });
  });
}
