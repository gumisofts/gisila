/// Merges the metrics of every isolate that serves the same port, so a
/// scrape that lands on any one of them reports the whole process.
library gisila.runtime.metrics.metrics_hub;

import 'dart:async';
import 'dart:isolate';

import 'metrics.dart';

/// Lives in one isolate (usually the main one). Pass [sendPort] to every
/// isolate's `MetricsConfig(hub: ...)`; each app joins when it builds its
/// handler, and a scrape on any of them gathers and sums all of them.
///
/// ```dart
/// final hub = MetricsHub();
/// for (var i = 0; i < Platform.numberOfProcessors; i++) {
///   await Isolate.spawn(runServer, hub.sendPort);
/// }
/// await runServer(hub.sendPort);
///
/// Future<void> runServer(SendPort hub) async {
///   final app =
///       GisilaApp(config: AppConfig(metrics: MetricsConfig(hub: hub)));
///   ...
/// }
/// ```
class MetricsHub {
  MetricsHub({this.collectTimeout = const Duration(seconds: 2)}) {
    _port.listen(_onMessage);
  }

  /// How long a scrape waits for each isolate's numbers.
  final Duration collectTimeout;

  final ReceivePort _port = ReceivePort('gisila.metrics_hub');
  final Map<SendPort, int> _members = <SendPort, int>{};

  /// A member that misses this many collections in a row (it exited) is
  /// dropped.
  static const int maxMisses = 3;

  SendPort get sendPort => _port.sendPort;

  /// Number of isolates currently joined.
  int get memberCount => _members.length;

  void close() => _port.close();

  void _onMessage(Object? message) {
    if (message is! List || message.length != 2) return;
    final [kind, port] = message;
    if (port is! SendPort) return;
    switch (kind) {
      case 'join':
        _members[port] = 0;
      case 'leave':
        _members.remove(port);
      case 'scrape':
        unawaited(_collect().then(port.send));
    }
  }

  Future<Map<String, Object?>> _collect() async {
    final members = _members.keys.toList();
    final replies = await Future.wait(members.map((m) async {
      final rp = ReceivePort();
      try {
        m.send(['collect', rp.sendPort]);
        final snap = await rp.first.timeout(collectTimeout);
        _members.update(m, (_) => 0, ifAbsent: () => 0);
        return (snap as Map).cast<String, Object?>();
      } on TimeoutException {
        final misses = (_members[m] ?? 0) + 1;
        if (misses >= maxMisses) {
          _members.remove(m);
        } else if (_members.containsKey(m)) {
          _members[m] = misses;
        }
        return null;
      } finally {
        rp.close();
      }
    }));
    return mergeSnapshots(replies.whereType<Map<String, Object?>>());
  }
}

/// One isolate's link to a [MetricsHub].
class MetricsHubMember {
  MetricsHubMember(this.hub, this.registry) {
    _port.listen((message) {
      if (message is List && message.length == 2 && message[0] == 'collect') {
        (message[1] as SendPort).send(registry.snapshot());
      }
    });
    hub.send(['join', _port.sendPort]);
  }

  final SendPort hub;
  final MetricsRegistry registry;
  final ReceivePort _port = ReceivePort('gisila.metrics_member');

  /// All isolates' metrics, merged. Falls back to this isolate's alone if
  /// the hub doesn't answer within [timeout].
  Future<Map<String, Object?>> scrape(
      {Duration timeout = const Duration(seconds: 5)}) async {
    final rp = ReceivePort();
    try {
      hub.send(['scrape', rp.sendPort]);
      final merged = await rp.first.timeout(timeout);
      return (merged as Map).cast<String, Object?>();
    } on TimeoutException {
      return registry.snapshot();
    } finally {
      rp.close();
    }
  }

  void close() {
    hub.send(['leave', _port.sendPort]);
    _port.close();
  }
}
