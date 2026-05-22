/// Request-id middleware.
///
/// Generates (or trusts) a stable request id and forwards it via the
/// configured response header. Also stores the id on the request
/// context for the logger.
library gisila.runtime.middleware.request_id;

import 'dart:math';

import 'package:shelf/shelf.dart';

import '../context.dart';

/// Returns a Shelf middleware that ensures every request has a
/// [RequestContext] attached.
///
/// * [headerName] - if the incoming request carries a value under this
///   header, it is reused as the request id; otherwise a random id is
///   minted. The same id is echoed back on the response.
/// * [generator] - override the default id generator (e.g. plug in
///   `uuid`).
Middleware requestIdMiddleware({
  String headerName = 'X-Request-Id',
  String Function()? generator,
}) {
  final gen = generator ?? _defaultRequestId;
  final lcHeader = headerName.toLowerCase();
  return (Handler inner) {
    return (Request request) async {
      final incoming = request.headers[lcHeader];
      final id = (incoming != null && incoming.isNotEmpty) ? incoming : gen();

      var ctx = RequestContext.maybeOf(request);
      ctx ??= RequestContext(requestId: id, request: request);

      final req = request.change(context: {
        ...request.context,
        kContextKey: ctx,
      });
      final response = await inner(req);
      return response.change(headers: <String, String>{
        ...response.headersAll.map((k, v) => MapEntry(k, v.join(','))),
        headerName: id,
      });
    };
  };
}

final _rng = Random.secure();
const _alphabet =
    'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

String _defaultRequestId() {
  final chars = List<String>.generate(
    16,
    (_) => _alphabet[_rng.nextInt(_alphabet.length)],
    growable: false,
  );
  return chars.join();
}
