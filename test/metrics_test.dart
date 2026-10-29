import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:gisila/gisila.dart';
import 'package:gisila/testing.dart';
import 'package:test/test.dart';

import 'fixtures/guarded_controller.dart';

const _token = 'a-metrics-token-of-length';

GisilaApp _app(MetricsConfig metrics) {
  final app = GisilaApp(
      config: AppConfig(
          logRequests: false,
          metrics: metrics,
          authenticator: const StaticTokenAuthenticator(
              {'r': Principal(id: 'u')})));
  app.registerController(
      attacher: (a, router, {prefix = ''}) =>
          GuardedController().attachToApp(a, router, prefix: prefix));
  return app;
}

class _Conn implements HttpConnectionInfo {
  _Conn(String ip) : remoteAddress = InternetAddress(ip);
  @override
  final InternetAddress remoteAddress;
  @override
  int get localPort => 8080;
  @override
  int get remotePort => 5555;
}

Request _scrape(String ip, {Map<String, String> headers = const {}}) =>
    Request('GET', Uri.parse('http://localhost/metrics'),
        headers: headers, context: {'shelf.io.connection_info': _Conn(ip)});

void main() {
  group('MetricsRegistry', () {
    test('renders counters, gauges and histograms', () {
      final r = MetricsRegistry();
      r.counter('jobs_total', help: 'Jobs run.', labels: ['kind'])
        ..inc({'kind': 'mail'})
        ..inc({'kind': 'mail'}, 2);
      r.gauge('queue_depth', help: 'Queued.').set(4);
      r.histogram('job_seconds', help: 'Job time.', buckets: [0.1, 1])
        ..observe(0.05)
        ..observe(0.5)
        ..observe(3);
      final text = r.render();
      expect(text, contains('# TYPE jobs_total counter\n'));
      expect(text, contains('jobs_total{kind="mail"} 3\n'));
      expect(text, contains('queue_depth 4\n'));
      expect(text, contains('job_seconds_bucket{le="0.1"} 1\n'));
      expect(text, contains('job_seconds_bucket{le="1"} 2\n'));
      expect(text, contains('job_seconds_bucket{le="+Inf"} 3\n'));
      expect(text, contains('job_seconds_sum 3.55\n'));
      expect(text, contains('job_seconds_count 3\n'));
      expect(text, contains('process_resident_memory_bytes '));
    });

    test('escapes label values', () {
      final r = MetricsRegistry();
      r.counter('x_total', help: 'X.', labels: ['v']).inc({'v': 'a"b\\c\nd'});
      expect(r.render(), contains(r'x_total{v="a\"b\\c\nd"} 1'));
    });

    test('validates names, labels and reuse', () {
      final r = MetricsRegistry();
      expect(() => r.counter('bad-name', help: ''), throwsArgumentError);
      expect(() => r.counter('ok', help: '', labels: ['le']),
          throwsArgumentError);
      final c = r.counter('c_total', help: '', labels: ['a']);
      expect(r.counter('c_total', help: ''), same(c));
      expect(() => r.gauge('c_total', help: ''), throwsStateError);
      expect(() => c.inc({'b': '1'}), throwsArgumentError);
      expect(() => c.inc({'a': '1'}, -1), throwsArgumentError);
    });

    test('mergeSnapshots sums matching series', () {
      MetricsRegistry make(int n) {
        final r = MetricsRegistry();
        r.counter('c_total', help: 'C.', labels: ['a']).inc({'a': 'x'}, n);
        r.histogram('h', help: 'H.', buckets: [1]).observe(n);
        return r;
      }

      final merged = mergeSnapshots([make(1).snapshot(), make(2).snapshot()]);
      final text = renderSnapshot(merged);
      expect(text, contains('c_total{a="x"} 3\n'));
      expect(text, contains('h_bucket{le="1"} 1\n'));
      expect(text, contains('h_count 2\n'));
      expect(text, contains('h_sum 3\n'));
    });
  });

  group('metrics middleware', () {
    test('labels requests by route template, method and status', () async {
      final app = _app(const MetricsConfig(bearerToken: _token));
      final c = GisilaTestClient(app);
      await c.get('/x/items/1');
      await c.get('/x/items/2');
      await c.get('/x/me');
      await c.get('/wp-login.php');
      final total = app.metrics.counter('http_server_requests_total',
          help: '', labels: ['method', 'route', 'status']);
      expect(
          total.value(
              {'method': 'GET', 'route': '/x/items/<id>', 'status': '200'}),
          2);
      expect(total.value({'method': 'GET', 'route': '/x/me', 'status': '401'}),
          1);
      expect(
          total.value({'method': 'GET', 'route': 'unmatched', 'status': '404'}),
          1);

      final res = await c.withToken(_token).get('/metrics');
      expect(res.statusCode, 200);
      expect(res.headers['content-type'], startsWith('text/plain'));
      expect(
          res.body,
          contains('http_server_request_duration_seconds_count'
              '{method="GET",route="/x/items/<id>"} 2'));
      expect(res.body, isNot(contains('route="/metrics"')));
    });

    test('the endpoint is hidden without the token', () async {
      final c =
          GisilaTestClient(_app(const MetricsConfig(bearerToken: _token)));
      expect((await c.get('/metrics')).statusCode, 404);
      expect((await c.withToken('wrong').get('/metrics')).statusCode, 404);
    });

    test('by default only direct loopback connections may scrape', () async {
      final h = _app(const MetricsConfig()).buildHandler();
      expect((await h(_scrape('127.0.0.1'))).statusCode, 200);
      expect((await h(_scrape('::1'))).statusCode, 200);
      expect((await h(_scrape('10.0.0.5'))).statusCode, 404);
      // A proxy on the same host forwarding a public request.
      expect(
          (await h(_scrape('127.0.0.1',
                  headers: {'x-forwarded-for': '203.0.113.9'})))
              .statusCode,
          404);
      expect((await h(Request('GET', Uri.parse('http://x/metrics'))))
              .statusCode,
          404);
    });

    test('allow decides when given', () async {
      final h = _app(MetricsConfig(
              allow: (r) => r.headers['x-scraper'] == 'prometheus'))
          .buildHandler();
      final res =
          await h(_scrape('10.0.0.5', headers: {'x-scraper': 'prometheus'}));
      expect(res.statusCode, 200);
      expect((await h(_scrape('127.0.0.1'))).statusCode, 404);
    });

    test('short tokens are refused', () {
      final app = _app(const MetricsConfig(bearerToken: 'short'));
      expect(app.buildHandler, throwsArgumentError);
    });

    test('scrapes a real server over loopback', () async {
      final app = _app(const MetricsConfig());
      final server = await app.start(host: '127.0.0.1', port: 0);
      addTearDown(app.stop);
      final client = HttpClient();
      addTearDown(client.close);
      Future<(int, String)> get(String path) async {
        final res = await (await client
                .getUrl(Uri.parse('http://127.0.0.1:${server.port}$path')))
            .close();
        return (res.statusCode, await utf8.decodeStream(res));
      }

      await get('/x/public');
      final (status, body) = await get('/metrics');
      expect(status, 200);
      expect(
          body,
          contains('http_server_requests_total'
              '{method="GET",route="/x/public",status="200"} 1'));
    });
  });

  group('MetricsHub', () {
    test('merges members in this isolate', () async {
      final hub = MetricsHub();
      addTearDown(hub.close);
      final a = _app(MetricsConfig(bearerToken: _token, hub: hub.sendPort));
      final b = _app(MetricsConfig(bearerToken: _token, hub: hub.sendPort));
      final ca = GisilaTestClient(a);
      final cb = GisilaTestClient(b);
      await ca.get('/x/public');
      await cb.get('/x/public');
      await cb.get('/x/public');
      final body = (await ca.withToken(_token).get('/metrics')).body;
      expect(
          body,
          contains('http_server_requests_total'
              '{method="GET",route="/x/public",status="200"} 3'));
      await a.stop();
      await b.stop();
    });

    test('merges a spawned isolate and drops it once it is gone', () async {
      final hub = MetricsHub(collectTimeout: const Duration(milliseconds: 200));
      addTearDown(hub.close);
      final ready = ReceivePort();
      final isolate =
          await Isolate.spawn(_worker, [hub.sendPort, ready.sendPort]);
      final stop = await ready.first as SendPort;

      final app = _app(MetricsConfig(bearerToken: _token, hub: hub.sendPort));
      final c = GisilaTestClient(app);
      final body = (await c.withToken(_token).get('/metrics')).body;
      expect(body, contains('worker_jobs_total 5'));
      expect(hub.memberCount, 2);

      stop.send(null);
      isolate.kill(priority: Isolate.immediate);
      for (var i = 0; i < MetricsHub.maxMisses; i++) {
        await c.withToken(_token).get('/metrics');
      }
      expect(hub.memberCount, 1);
      await app.stop();
    });
  });
}

void _worker(List<Object?> args) {
  final hub = args[0] as SendPort;
  final ready = args[1] as SendPort;
  final registry = MetricsRegistry();
  registry.counter('worker_jobs_total', help: 'Jobs.').inc(const {}, 5);
  MetricsHubMember(hub, registry);
  final stop = ReceivePort();
  ready.send(stop.sendPort);
}
