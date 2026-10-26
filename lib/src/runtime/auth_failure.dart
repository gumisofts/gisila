/// Turns an exception thrown by an [Authenticator] into the 401 sent back.
library gisila.runtime.auth_failure;

import 'app.dart';
import 'exceptions.dart';

/// An [HttpException] the authenticator threw on purpose (`Unauthorized('Token
/// expired')`, a 403) goes out as is. Anything else (a JWT library error, a
/// database exception) can carry internals, so the client gets a generic 401
/// and the detail goes to the log.
HttpException authFailure(
  GisilaApp? app,
  Object error,
  StackTrace stackTrace, {
  String? requestId,
}) {
  if (error is HttpException &&
      (error.statusCode == 401 || error.statusCode == 403)) {
    return error;
  }
  app?.config.logger.warning(
    'Authenticator threw; answering 401',
    fields: <String, Object?>{if (requestId != null) 'request_id': requestId},
    error: error,
    stackTrace: stackTrace,
  );
  return Unauthorized();
}
