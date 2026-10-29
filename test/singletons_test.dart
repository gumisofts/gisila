import 'package:gisila/gisila.dart';
import 'package:gisila/testing.dart';
import 'package:test/test.dart';

class Mailer {
  Mailer(this.from);
  final String from;
}

class Clock {
  Clock(this.mailer);
  final Mailer mailer;
}

class Greeter extends Service {
  String greet() => 'hi from ${singleton<Mailer>().from}';
}

GisilaApp _app() {
  final app = GisilaApp(config: AppConfig(logRequests: false));
  app.registerService<Greeter>(Greeter.new);
  app.registerController(attacher: (a, router, {prefix = ''}) {
    router.get('/ctx', (Request r) {
      final ctx = RequestContext.maybeOf(r)!;
      return jsonResponse(body: {'from': ctx.singleton<Mailer>().from});
    });
    router.get('/svc', (Request r) {
      final ctx = RequestContext.maybeOf(r)!;
      return jsonResponse(body: {'msg': ctx.service<Greeter>().greet()});
    });
  });
  return app;
}

void main() {
  test('instances are reachable from the app, context and services',
      () async {
    final app = _app()..registerSingleton(Mailer('noreply@x'));
    expect(app.singleton<Mailer>().from, 'noreply@x');
    final client = GisilaTestClient(app);
    expect((await client.get('/ctx')).jsonMap, {'from': 'noreply@x'});
    expect((await client.get('/svc')).jsonMap, {'msg': 'hi from noreply@x'});
  });

  test('factories run in order during init and see earlier singletons',
      () async {
    final app = _app()
      ..registerSingletonFactory<Mailer>((_) async => Mailer('async@x'))
      ..registerSingletonFactory<Clock>((a) => Clock(a.singleton<Mailer>()));
    expect(() => app.singleton<Mailer>(), throwsStateError);
    await app.init();
    await app.init(); // runs once
    expect(app.singleton<Clock>().mailer.from, 'async@x');
    expect((await GisilaTestClient(app).get('/ctx')).jsonMap,
        {'from': 'async@x'});
  });

  test('unknown and duplicate registrations fail clearly', () async {
    final app = _app()..registerSingleton(Mailer('a'));
    expect(() => app.singleton<Clock>(), throwsStateError);
    expect(() => app.registerSingleton(Mailer('b')), throwsStateError);
    await app.init();
    expect(() => app.registerSingleton(Clock(Mailer('c'))), throwsStateError);
  });

  test('hooks and disposal run in order on start and stop', () async {
    final log = <String>[];
    final app = _app()
      ..registerSingleton(Mailer('m'), dispose: (_) => log.add('dispose mailer'))
      ..registerSingletonFactory<Clock>((a) {
        log.add('create clock');
        return Clock(a.singleton<Mailer>());
      }, dispose: (_) => log.add('dispose clock'))
      ..onStart(() => log.add('start 1'))
      ..onStart(() async => log.add('start 2'))
      ..onStop(() => log.add('stop 1'))
      ..onStop(() => throw StateError('broken hook'))
      ..onStop(() => log.add('stop 3'));

    final server = await app.start(host: '127.0.0.1', port: 0);
    expect(server.port, isNonZero);
    expect(log, ['create clock', 'start 1', 'start 2']);
    log.clear();

    await app.stop();
    expect(log, ['stop 3', 'stop 1', 'dispose clock', 'dispose mailer']);
    expect(() => app.singleton<Clock>(), throwsStateError);
    expect(app.singleton<Mailer>().from, 'm'); // given, not created
  });

  test('stop() tears down an app that was only inited', () async {
    var stopped = false;
    final app = _app()..onStop(() => stopped = true);
    await app.init();
    await app.stop();
    expect(stopped, isTrue);
  });

  test('a failing start undoes what was set up and can be retried',
      () async {
    final log = <String>[];
    var fail = true;
    final app = _app()
      ..registerSingletonFactory<Mailer>((_) => Mailer('m'),
          dispose: (_) => log.add('dispose mailer'))
      ..onStart(() {
        if (fail) throw StateError('no db');
      })
      ..onStop(() => log.add('stop hook'));

    await expectLater(app.init(), throwsStateError);
    expect(log, ['dispose mailer']);
    expect(() => app.singleton<Mailer>(), throwsStateError);

    fail = false;
    await app.init();
    expect(app.singleton<Mailer>().from, 'm');
  });
}
