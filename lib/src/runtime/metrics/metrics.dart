/// A small Prometheus-style metrics registry: counters, gauges and
/// histograms with labels, rendered in the text exposition format.
library gisila.runtime.metrics.metrics;

import 'dart:io' show ProcessInfo;

final _nameRe = RegExp(r'^[a-zA-Z_:][a-zA-Z0-9_:]*$');
final _labelRe = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');

/// Default histogram buckets, in seconds.
const List<double> defaultLatencyBuckets = <double>[
  0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10, //
];

/// Holds an app's metrics. [GisilaApp.metrics] is one; the framework's
/// HTTP metrics live there next to yours.
///
/// Label values should come from a small fixed set (a route template, a
/// status code), never from user input such as raw paths or ids: every
/// distinct combination is kept in memory forever.
class MetricsRegistry {
  // Top-level finals are lazy: read it now so it records when the app
  // was built, not the first scrape.
  MetricsRegistry() {
    _processStart;
  }

  final Map<String, _Metric> _metrics = <String, _Metric>{};

  /// A counter (only goes up). Calling again with the same name returns
  /// the same counter.
  Counter counter(String name,
          {required String help, List<String> labels = const []}) =>
      _register(name, () => Counter._(name, help, labels));

  /// A gauge (a value that goes up and down).
  Gauge gauge(String name,
          {required String help, List<String> labels = const []}) =>
      _register(name, () => Gauge._(name, help, labels));

  /// A histogram of observed values (latencies, sizes) in [buckets].
  Histogram histogram(String name,
      {required String help,
      List<String> labels = const [],
      List<double> buckets = defaultLatencyBuckets}) {
    return _register(
        name, () => Histogram._(name, help, labels, List.of(buckets)..sort()));
  }

  T _register<T extends _Metric>(String name, T Function() create) {
    final existing = _metrics[name];
    if (existing != null) {
      if (existing is! T) {
        throw StateError('Metric $name is already a ${existing._type}.');
      }
      return existing;
    }
    if (!_nameRe.hasMatch(name)) {
      throw ArgumentError.value(name, 'name', 'is not a valid metric name');
    }
    final metric = create();
    for (final l in metric.labelNames) {
      if (!_labelRe.hasMatch(l) || l.startsWith('__') || l == 'le') {
        throw ArgumentError.value(l, 'labels', 'is not a valid label name');
      }
    }
    return _metrics[name] = metric;
  }

  /// A plain-data copy of every metric, sendable to another isolate and
  /// mergeable with [mergeSnapshots].
  Map<String, Object?> snapshot() => <String, Object?>{
        for (final m in _metrics.values) m.name: m._snapshot(),
      };

  /// This registry in the Prometheus text format, plus process metrics.
  String render() => renderSnapshot(snapshot());
}

abstract class _Metric {
  _Metric(this.name, this.help, List<String> labels)
      : labelNames = List.unmodifiable(labels);

  final String name;
  final String help;
  final List<String> labelNames;

  String get _type;

  String _key(Map<String, String> labels) {
    if (labels.length != labelNames.length ||
        !labelNames.every(labels.containsKey)) {
      throw ArgumentError.value(
          labels, 'labels', '$name takes exactly $labelNames');
    }
    return labelNames.map((l) => labels[l]).join('\u0000');
  }

  Map<String, Object?> _snapshot() => <String, Object?>{
        'type': _type,
        'help': help,
        'labels': labelNames,
        'series': _series(),
      };

  Map<String, Object?> _series();
}

class Counter extends _Metric {
  Counter._(super.name, super.help, super.labels);

  final Map<String, double> _values = <String, double>{};

  @override
  String get _type => 'counter';

  /// Adds [by] (default 1, never negative).
  void inc([Map<String, String> labels = const {}, num by = 1]) {
    if (by < 0) throw ArgumentError.value(by, 'by', 'must not be negative');
    final k = _key(labels);
    _values[k] = (_values[k] ?? 0) + by;
  }

  double value([Map<String, String> labels = const {}]) =>
      _values[_key(labels)] ?? 0;

  @override
  Map<String, Object?> _series() => Map.of(_values);
}

class Gauge extends _Metric {
  Gauge._(super.name, super.help, super.labels);

  final Map<String, double> _values = <String, double>{};

  @override
  String get _type => 'gauge';

  void set(num value, [Map<String, String> labels = const {}]) =>
      _values[_key(labels)] = value.toDouble();

  void inc([Map<String, String> labels = const {}, num by = 1]) {
    final k = _key(labels);
    _values[k] = (_values[k] ?? 0) + by;
  }

  void dec([Map<String, String> labels = const {}, num by = 1]) =>
      inc(labels, -by);

  double value([Map<String, String> labels = const {}]) =>
      _values[_key(labels)] ?? 0;

  @override
  Map<String, Object?> _series() => Map.of(_values);
}

class Histogram extends _Metric {
  Histogram._(super.name, super.help, super.labels, this.buckets);

  final List<double> buckets;

  /// Per series: a count per bucket (not cumulative), then sum, then count.
  final Map<String, List<double>> _values = <String, List<double>>{};

  @override
  String get _type => 'histogram';

  void observe(num value, [Map<String, String> labels = const {}]) {
    final v = _values.putIfAbsent(
        _key(labels), () => List<double>.filled(buckets.length + 2, 0));
    final i = buckets.indexWhere((b) => value <= b);
    if (i >= 0) v[i]++;
    v[buckets.length] += value;
    v[buckets.length + 1]++;
  }

  /// Times [body] and observes the duration in seconds.
  Future<T> time<T>(Future<T> Function() body,
      [Map<String, String> labels = const {}]) async {
    final sw = Stopwatch()..start();
    try {
      return await body();
    } finally {
      observe(sw.elapsedMicroseconds / 1e6, labels);
    }
  }

  @override
  Map<String, Object?> _snapshot() =>
      {...super._snapshot(), 'buckets': buckets};

  @override
  Map<String, Object?> _series() =>
      {for (final e in _values.entries) e.key: List.of(e.value)};
}

/// Adds snapshots from several isolates together: counters, gauges and
/// histograms with the same name and labels are summed. A metric whose
/// type or buckets differ from the first one seen is dropped.
Map<String, Object?> mergeSnapshots(Iterable<Map<String, Object?>> snaps) {
  final out = <String, Map<String, Object?>>{};
  for (final snap in snaps) {
    for (final e in snap.entries) {
      final m = e.value as Map;
      final seen = out[e.key];
      if (seen == null) {
        out[e.key] = {
          ...m.cast<String, Object?>(),
          'series': {
            for (final s in (m['series'] as Map).entries)
              s.key as String:
                  s.value is List ? List.of(s.value as List) : s.value,
          },
        };
        continue;
      }
      if (seen['type'] != m['type'] ||
          '${seen['buckets']}' != '${m['buckets']}') {
        continue;
      }
      final series = seen['series'] as Map<String, Object?>;
      for (final s in (m['series'] as Map).entries) {
        final key = s.key as String;
        final mine = series[key];
        if (mine == null) {
          series[key] = s.value is List ? List.of(s.value as List) : s.value;
        } else if (mine is List) {
          final theirs = s.value as List;
          for (var i = 0; i < mine.length && i < theirs.length; i++) {
            mine[i] = (mine[i] as num) + (theirs[i] as num);
          }
        } else {
          series[key] = (mine as num) + (s.value as num);
        }
      }
    }
  }
  return out;
}

final DateTime _processStart = DateTime.now();

/// Renders a snapshot (one isolate's or a merged one) in the Prometheus
/// text format, followed by process-wide metrics.
String renderSnapshot(Map<String, Object?> snapshot) {
  final b = StringBuffer();
  for (final e in snapshot.entries) {
    final name = e.key;
    final m = e.value as Map;
    final labelNames = (m['labels'] as List).cast<String>();
    b
      ..writeln('# HELP $name ${_escapeHelp(m['help'] as String)}')
      ..writeln('# TYPE $name ${m['type']}');
    final series = (m['series'] as Map).cast<String, Object?>();
    for (final s in series.entries) {
      final values =
          labelNames.isEmpty ? const <String>[] : s.key.split('\u0000');
      final labels = <String, String>{
        for (var i = 0; i < labelNames.length; i++) labelNames[i]: values[i],
      };
      if (m['type'] == 'histogram') {
        final buckets = (m['buckets'] as List).cast<num>();
        final v = (s.value as List).cast<num>();
        num cumulative = 0;
        for (var i = 0; i < buckets.length; i++) {
          cumulative += v[i];
          b.writeln('${name}_bucket${_labels({
                ...labels,
                'le': _num(buckets[i])
              })} ${_num(cumulative)}');
        }
        b
          ..writeln('${name}_bucket${_labels({...labels, 'le': '+Inf'})} '
              '${_num(v[buckets.length + 1])}')
          ..writeln('${name}_sum${_labels(labels)} ${_num(v[buckets.length])}')
          ..writeln(
              '${name}_count${_labels(labels)} ${_num(v[buckets.length + 1])}');
      } else {
        b.writeln('$name${_labels(labels)} ${_num(s.value as num)}');
      }
    }
  }
  b
    ..writeln('# HELP process_resident_memory_bytes Resident memory size.')
    ..writeln('# TYPE process_resident_memory_bytes gauge')
    ..writeln('process_resident_memory_bytes ${ProcessInfo.currentRss}')
    ..writeln('# HELP process_start_time_seconds Start time since the epoch.')
    ..writeln('# TYPE process_start_time_seconds gauge')
    ..writeln('process_start_time_seconds '
        '${_processStart.millisecondsSinceEpoch ~/ 1000}');
  return b.toString();
}

String _labels(Map<String, String> labels) {
  if (labels.isEmpty) return '';
  final parts =
      labels.entries.map((e) => '${e.key}="${_escapeLabel(e.value)}"');
  return '{${parts.join(',')}}';
}

String _escapeLabel(String v) =>
    v.replaceAll(r'\', r'\\').replaceAll('"', r'\"').replaceAll('\n', r'\n');

String _escapeHelp(String v) =>
    v.replaceAll(r'\', r'\\').replaceAll('\n', r'\n');

String _num(num v) {
  if (v == v.roundToDouble() && v.abs() < 1e15) return v.toInt().toString();
  return v.toString();
}
