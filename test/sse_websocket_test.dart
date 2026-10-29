import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:gisila/gisila.dart';
import 'package:gisila/testing.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:test/test.dart';

void main() {
  group('SseEvent', () {
    test('encodes fields and splits data lines', () {
      expect(
          const SseEvent(
                  data: 'a\nb\r\nc',
                  event: 'order',
                  id: '7',
                  retry: Duration(seconds: 3),
                  comment: 'hi')
              .encode(),
          ': hi\nevent: order\nid: 7\nretry: 3000\n'
          'data: a\ndata: b\ndata: c\n\n');
      expect(SseEvent.json({'x': 1}).encode(), 'data: {"x":1}\n\n');
    });

    test('refuses line breaks in event and id', () {
      expect(() => const SseEvent(event: 'a\nb').encode(), throwsArgumentError);
      expect(() => const SseEvent(id: '1\r').encode(), throwsArgumentError);
    });
  });

  test('sseResponse sets stream headers and unbuffered output', () async {
    final res = sseResponse(
        Stream.fromIterable(
            [const SseEvent(data: 'one'), const SseEvent(data: 'two')]),
        keepAlive: null);
    expect(res.headers['content-type'], 'text/event-stream; charset=utf-8');
    expect(res.headers['cache-control'], 'no-cache');
    expect(res.context['shelf.io.buffer_output'], false);
    expect(await res.readAsString(), 'data: one\n\ndata: two\n\n');
  });

  group('over a real server', () {
    late GisilaApp app;
    late HttpServer server;
    late StreamController<SseEvent> events;
    late Completer<void> cancelled;
    final logs = <LogEvent>[];

    setUp(() async {
      events = StreamController<SseEvent>();
      cancelled = Completer<void>();
      events.onCancel = () {
        if (!cancelled.isCompleted) cancelled.complete();
      };
      logs.clear();
      app = GisilaApp(
          config: AppConfig(
        logger: _ListLogger(logs),
        logResponseBody: true,
        compression: const CompressionConfig(),
        etags: const EtagConfig(),
        metrics: const MetricsConfig(),
        requestTimeout: const Duration(seconds: 5),
        authenticator:
            const StaticTokenAuthenticator({'t': Principal(id: 'u1')}),
      ));
      app.registerController(attacher: (a, router, {prefix = ''}) {
        router.get(
            '/events',
            gisilaRoute(
                app: a,
                config: const RouteConfig(requireAuth: true),
                routeId: 'GET /events',
                handler: (ctx) => sseResponse(events.stream,
                    keepAlive: const Duration(milliseconds: 100))));
        router.get(
            '/ws',
            gisilaRoute(
                app: a,
                config: const RouteConfig(requireAuth: true),
                routeId: 'GET /ws',
                handler: (ctx) => webSocketHandler((channel, _) {
                      channel.stream.listen((m) =>
                          channel.sink.add('${ctx.principal!.id}: $m'));
                    })(ctx.request)));
      });
      server = await app.start(host: '127.0.0.1', port: 0);
    });

    tearDown(() => app.stop(force: true));

    test('events arrive as sent and a disconnect cancels the source',
        () async {
      final client = HttpClient();
      final req = await client
          .getUrl(Uri.parse('http://127.0.0.1:${server.port}/events'));
      req.headers.set('authorization', 'Bearer t');
      req.headers.set('accept-encoding', 'gzip');
      final res = await req.close();
      expect(res.statusCode, 200);
      expect(res.headers.value('content-encoding'), isNull);

      final chunks = StreamIterator(res.transform(utf8.decoder));
      events.add(const SseEvent(data: 'first'));
      var received = '';
      Future<void> readUntil(String text) async {
        while (!received.contains(text)) {
          expect(await chunks.moveNext().timeout(const Duration(seconds: 2)),
              isTrue);
          received += chunks.current;
        }
      }

      await readUntil('data: first');
      await readUntil(':\n\n'); // keep-alive while idle

      client.close(force: true);
      await cancelled.future.timeout(const Duration(seconds: 5));
    });

    test('SSE routes keep their guards', () async {
      final client = HttpClient();
      final res = await (await client
              .getUrl(Uri.parse('http://127.0.0.1:${server.port}/events')))
          .close();
      expect(res.statusCode, 401);
      client.close(force: true);
    });

    test('a WebSocket upgrades through the guarded pipeline', () async {
      final ws = await WebSocket.connect('ws://127.0.0.1:${server.port}/ws',
          headers: {'authorization': 'Bearer t'});
      ws.add('hello');
      expect(await ws.first.timeout(const Duration(seconds: 2)), 'u1: hello');
      await ws.close();

      expect(logs.where((e) => e.level == LogLevel.error), isEmpty);
      expect(logs.map((e) => e.message), contains(contains('101 upgraded')));
      expect(
          app.metrics.render(),
          contains('http_server_requests_total'
              '{method="GET",route="/ws",status="101"} 1'));
    });

    test('an unauthenticated WebSocket is refused before the upgrade',
        () async {
      await expectLater(WebSocket.connect('ws://127.0.0.1:${server.port}/ws'),
          throwsA(isA<WebSocketException>()));
    });
  });

  test('the test client reads a finite SSE stream', () async {
    final app = GisilaApp(config: AppConfig(logRequests: false));
    app.registerController(attacher: (a, router, {prefix = ''}) {
      router.get(
          '/e',
          (Request r) => sseResponse(
              Stream.value(SseEvent(data: 'x', id: lastEventId(r) ?? '0')),
              keepAlive: null));
    });
    final res = await GisilaTestClient(app)
        .get('/e', headers: {'last-event-id': '41'});
    expect(res.body, 'id: 41\ndata: x\n\n');
  });
}

class _ListLogger extends Logger {
  _ListLogger(this.events);
  final List<LogEvent> events;

  @override
  LogLevel get level => LogLevel.debug;

  @override
  void log(LogEvent event) => events.add(event);
}
