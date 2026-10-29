/// Server-sent events (`text/event-stream`).
library gisila.runtime.sse;

import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart';

/// One server-sent event.
class SseEvent {
  const SseEvent({this.data, this.event, this.id, this.retry, this.comment});

  /// Text sent as `data:` lines; line breaks become separate lines, which
  /// the browser joins back with `\n`.
  final String? data;

  /// Event type, for `eventSource.addEventListener(type, ...)`.
  final String? event;

  /// Sent back by a reconnecting browser as `Last-Event-ID` (see
  /// [lastEventId]).
  final String? id;

  /// How long the browser waits before reconnecting.
  final Duration? retry;

  /// A `:` comment line; browsers ignore it.
  final String? comment;

  /// An event whose data is [value] JSON-encoded.
  factory SseEvent.json(Object? value, {String? event, String? id}) =>
      SseEvent(data: jsonEncode(value), event: event, id: id);

  String encode() {
    String single(String name, String v) {
      if (v.contains('\n') || v.contains('\r')) {
        throw ArgumentError.value(v, name, 'must be a single line');
      }
      return v;
    }

    final b = StringBuffer();
    if (comment != null) {
      for (final line in comment!.split(_lineBreak)) {
        b.write(': $line\n');
      }
    }
    if (event != null) b.write('event: ${single('event', event!)}\n');
    if (id != null) {
      if (id!.contains('\u0000')) {
        throw ArgumentError.value(id, 'id', 'must not contain NUL');
      }
      b.write('id: ${single('id', id!)}\n');
    }
    if (retry != null) b.write('retry: ${retry!.inMilliseconds}\n');
    if (data != null) {
      for (final line in data!.split(_lineBreak)) {
        b.write('data: $line\n');
      }
    }
    b.write('\n');
    return b.toString();
  }

  static final _lineBreak = RegExp(r'\r\n|\r|\n');
}

/// The `Last-Event-ID` a reconnecting browser sent, so a stream can resume
/// after the last event the client saw.
String? lastEventId(Request request) => request.headers['last-event-id'];

/// A `text/event-stream` response sending [events] as they arrive.
///
/// ```dart
/// @Get('/orders/{id}/events')
/// Future<Response> events(String id, RequestContext ctx, OrderService orders) async =>
///     sseResponse(orders.updates(id).map((o) => SseEvent.json(o, event: 'order')));
/// ```
///
/// Output buffering is turned off so each event is sent at once, and a
/// comment goes out every [keepAlive] (pass `null` for none) so proxies
/// don't close an idle connection. When the client disconnects, the
/// subscription to [events] is cancelled; clean up in its `onCancel`. An
/// error on [events] ends the response.
Response sseResponse(
  Stream<SseEvent> events, {
  Duration? keepAlive = const Duration(seconds: 15),
  Map<String, String> headers = const {},
}) {
  late final StreamController<List<int>> out;
  StreamSubscription<SseEvent>? sub;
  Timer? timer;

  Future<void> stop() async {
    timer?.cancel();
    final s = sub;
    sub = null;
    await s?.cancel();
  }

  out = StreamController<List<int>>(
    onListen: () {
      sub = events.listen(
        (e) => out.add(utf8.encode(e.encode())),
        onError: (Object _, StackTrace __) {
          stop();
          out.close();
        },
        onDone: () {
          timer?.cancel();
          out.close();
        },
      );
      if (keepAlive != null) {
        timer = Timer.periodic(keepAlive, (_) {
          if (!out.isClosed) out.add(utf8.encode(':\n\n'));
        });
      }
    },
    onPause: () => sub?.pause(),
    onResume: () => sub?.resume(),
    onCancel: stop,
  );

  return Response.ok(
    out.stream,
    headers: {
      'content-type': 'text/event-stream; charset=utf-8',
      'cache-control': 'no-cache',
      // nginx would otherwise buffer the stream.
      'x-accel-buffering': 'no',
      ...headers,
    },
    context: const {'shelf.io.buffer_output': false},
  );
}
