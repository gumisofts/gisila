import 'dart:io';

import 'package:gisila/gisila.dart';
import 'package:gisila/testing.dart';
import 'package:test/test.dart';

import 'fixtures/guarded_controller.dart';

void main() {
  late Directory tmp;
  late Directory site;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('gisila_static_');
    site = Directory('${tmp.path}/site')..createSync();
    File('${site.path}/index.html').writeAsStringSync('<h1>home</h1>');
    File('${site.path}/app.js').writeAsStringSync('console.log(1)');
    Directory('${site.path}/assets').createSync();
    File('${site.path}/assets/app.1234abcd.js').writeAsStringSync('hashed');
    Directory('${site.path}/docs').createSync();
    File('${site.path}/docs/index.html').writeAsStringSync('<h1>docs</h1>');
    File('${site.path}/.env').writeAsStringSync('SECRET=1');
    File('${tmp.path}/outside.txt').writeAsStringSync('OUTSIDE-CONTENTS');
    Link('${site.path}/escape.txt').createSync('${tmp.path}/outside.txt');
    Link('${site.path}/inside.js').createSync('${site.path}/app.js');
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  GisilaTestClient client(
      {String prefix = '/',
      StaticFilesConfig config = const StaticFilesConfig()}) {
    final app = GisilaApp(config: AppConfig(logRequests: false));
    app.registerController(
        attacher: (a, router, {prefix = ''}) =>
            GuardedController().attachToApp(a, router, prefix: prefix));
    app.serveStatic(prefix, site.path, config: config);
    return GisilaTestClient(app);
  }

  test('serves files with type, length and validators', () async {
    final res = await client().get('/app.js');
    expect(res.statusCode, 200);
    expect(res.body, 'console.log(1)');
    expect(res.headers['content-type'], startsWith('text/javascript'));
    expect(res.headers['content-length'], '14');
    expect(res.headers['etag'], startsWith('W/"'));
    expect(res.headers['last-modified'], isNotNull);
    expect(res.headers['cache-control'], 'no-cache');
  });

  test('directories serve their index file', () async {
    final c = client();
    expect((await c.get('/')).body, '<h1>home</h1>');
    expect((await c.get('/docs/')).body, '<h1>docs</h1>');
    expect((await c.get('/docs')).body, '<h1>docs</h1>');
  });

  test('controllers win over a static mount at /', () async {
    final c = client();
    expect((await c.get('/x/public')).jsonMap, {'ok': true});
    final missing = await c.get('/nope.js');
    expect(missing.statusCode, 404);
    expect(missing.errorCode, 'not_found');
  });

  test('never serves dotfiles, traversal or symlinks out of the root',
      () async {
    final c = client();
    for (final path in [
      '/.env',
      '/../outside.txt',
      '/%2e%2e/outside.txt',
      '/assets/..%2F..%2Foutside.txt',
      '/escape.txt',
    ]) {
      final res = await c.get(path);
      expect(res.statusCode, 404, reason: path);
      expect(res.body, isNot(contains('OUTSIDE-CONTENTS')), reason: path);
      expect(res.body, isNot(contains('SECRET')), reason: path);
    }
    expect((await c.get('/inside.js')).body, 'console.log(1)');
  });

  test('ETag and If-Modified-Since answer 304', () async {
    final c = client();
    final first = await c.get('/app.js');
    final byTag = await c
        .get('/app.js', headers: {'if-none-match': first.headers['etag']!});
    expect(byTag.statusCode, 304);
    expect(byTag.body, isEmpty);
    final byDate = await c.get('/app.js',
        headers: {'if-modified-since': first.headers['last-modified']!});
    expect(byDate.statusCode, 304);
    final stale = await c.get('/app.js',
        headers: {'if-modified-since': 'Mon, 01 Jan 2001 00:00:00 GMT'});
    expect(stale.statusCode, 200);
  });

  test('cache lifetimes: maxAge, immutable, HTML always revalidated',
      () async {
    final c = client(
        config: StaticFilesConfig(
            maxAge: const Duration(hours: 1),
            immutable: RegExp(r'^assets/.*\.[0-9a-f]{8}\.')));
    expect((await c.get('/app.js')).headers['cache-control'],
        'public, max-age=3600');
    expect((await c.get('/assets/app.1234abcd.js')).headers['cache-control'],
        'public, max-age=31536000, immutable');
    expect((await c.get('/')).headers['cache-control'], 'no-cache');
  });

  test('SPA fallback serves index.html for page routes only', () async {
    final c = client(config: const StaticFilesConfig(spaFallback: true));
    final html = {'accept': 'text/html,application/xhtml+xml'};
    final page = await c.get('/orders/42', headers: html);
    expect(page.statusCode, 200);
    expect(page.body, '<h1>home</h1>');
    // API clients, missing assets and other methods still get 404.
    expect((await c.get('/orders/42')).statusCode, 404);
    expect((await c.get('/missing.js', headers: html)).statusCode, 404);
    expect((await c.post('/orders/42', headers: html)).statusCode, 404);
  });

  test('a prefix mount serves only below it', () async {
    final c = client(prefix: '/static');
    expect((await c.get('/static/app.js')).body, 'console.log(1)');
    expect((await c.get('/app.js')).statusCode, 404);
  });

  test('a missing directory fails at registration', () {
    final app = GisilaApp();
    expect(() => app.serveStatic('/', '${tmp.path}/nope'), throwsArgumentError);
    expect(() => app.serveStatic('static', site.path), throwsArgumentError);
  });
}
