/// An in-memory HTTP client for testing a [GisilaApp]: requests go through
/// `buildHandler()` (the full pipeline: guards, forms, error mapping) with
/// no server or socket.
library gisila.testing.test_client;

import 'dart:collection' show UnmodifiableMapView;
import 'dart:convert';

import 'package:http_parser/http_parser.dart' show CaseInsensitiveMap;
import 'package:shelf/shelf.dart';

import '../runtime/app.dart';
import '../runtime/auth/authenticator.dart';
import '../runtime/auth/principal.dart';

/// Sends requests straight into an app's handler.
///
/// ```dart
/// final client = GisilaTestClient(app);
/// final res = await client.withToken(token).post('/notes', json: {'title': 'a'});
/// expect(res.statusCode, 201);
/// expect(res.jsonMap['title'], 'a');
/// ```
///
/// Clients are immutable: [withToken], [withHeaders] and [as] return a new
/// one, so a shared base client can't leak credentials between tests.
class GisilaTestClient {
  /// Builds the app's handler once. Register controllers and services
  /// before creating the client.
  GisilaTestClient(GisilaApp app,
      {Map<String, String> headers = const {}, Uri? baseUri})
      : this._(app.buildHandler(), app.config.authenticator, headers,
            baseUri ?? _defaultBase);

  /// A client for any Shelf [handler] (a router mounted without
  /// [GisilaApp], say). [as] is not available.
  GisilaTestClient.handler(Handler handler,
      {Map<String, String> headers = const {}, Uri? baseUri})
      : this._(handler, null, headers, baseUri ?? _defaultBase);

  GisilaTestClient._(
      this._handler, this._authenticator, Map<String, String> headers,
      this.baseUri)
      : headers = Map.unmodifiable(headers);

  static final Uri _defaultBase = Uri.parse('http://localhost');

  final Handler _handler;
  final Authenticator? _authenticator;

  /// Headers sent with every request; per-request `headers` win.
  final Map<String, String> headers;

  /// Scheme and host requests are addressed to.
  final Uri baseUri;

  /// A client that sends `Authorization: Bearer <token>`.
  GisilaTestClient withToken(String token) =>
      withHeaders({'authorization': 'Bearer $token'});

  /// A client that also sends [extra].
  GisilaTestClient withHeaders(Map<String, String> extra) =>
      GisilaTestClient._(_handler, _authenticator,
          {...headers, ..._lower(extra)}, baseUri);

  /// A client authenticated as [principal]. The app's authenticator must
  /// be a [TestAuthenticator].
  GisilaTestClient as(Principal principal) {
    final auth = _authenticator;
    if (auth is! TestAuthenticator) {
      throw StateError('GisilaTestClient.as() needs '
          'AppConfig(authenticator: TestAuthenticator(...)); the app uses '
          '${auth?.runtimeType ?? 'no GisilaApp'}. Use withToken() with a '
          'real token instead.');
    }
    return withToken(auth.tokenFor(principal));
  }

  Future<TestResponse> get(String path,
          {Map<String, Object?>? query, Map<String, String>? headers}) =>
      request('GET', path, query: query, headers: headers);

  Future<TestResponse> head(String path,
          {Map<String, Object?>? query, Map<String, String>? headers}) =>
      request('HEAD', path, query: query, headers: headers);

  Future<TestResponse> options(String path,
          {Map<String, Object?>? query, Map<String, String>? headers}) =>
      request('OPTIONS', path, query: query, headers: headers);

  Future<TestResponse> post(String path,
          {Object? json,
          Map<String, String>? form,
          Object? body,
          String? contentType,
          Map<String, Object?>? query,
          Map<String, String>? headers}) =>
      request('POST', path,
          json: json,
          form: form,
          body: body,
          contentType: contentType,
          query: query,
          headers: headers);

  Future<TestResponse> put(String path,
          {Object? json,
          Map<String, String>? form,
          Object? body,
          String? contentType,
          Map<String, Object?>? query,
          Map<String, String>? headers}) =>
      request('PUT', path,
          json: json,
          form: form,
          body: body,
          contentType: contentType,
          query: query,
          headers: headers);

  Future<TestResponse> patch(String path,
          {Object? json,
          Map<String, String>? form,
          Object? body,
          String? contentType,
          Map<String, Object?>? query,
          Map<String, String>? headers}) =>
      request('PATCH', path,
          json: json,
          form: form,
          body: body,
          contentType: contentType,
          query: query,
          headers: headers);

  Future<TestResponse> delete(String path,
          {Object? json,
          Map<String, Object?>? query,
          Map<String, String>? headers}) =>
      request('DELETE', path, json: json, query: query, headers: headers);

  /// Sends one request. Give at most one body: [json] (encoded, with
  /// `application/json`), [form] (url-encoded), or a raw [body] (`String`
  /// or bytes) with its [contentType]. [query] values may be lists for
  /// repeated keys.
  Future<TestResponse> request(
    String method,
    String path, {
    Object? json,
    Map<String, String>? form,
    Object? body,
    String? contentType,
    Map<String, Object?>? query,
    Map<String, String>? headers,
  }) async {
    if ([json, form, body].whereType<Object>().length > 1) {
      throw ArgumentError('Give at most one of json, form and body.');
    }
    final Object? payload;
    String? type = contentType;
    if (json != null) {
      payload = jsonEncode(json);
      type ??= 'application/json';
    } else if (form != null) {
      payload = Uri(queryParameters: form).query;
      type ??= 'application/x-www-form-urlencoded';
    } else {
      payload = body;
    }

    final res = await _handler(Request(
      method,
      _uri(path, query),
      headers: {
        ...this.headers,
        if (type != null) 'content-type': type,
        ..._lower(headers ?? const {}),
      },
      body: payload,
    ));
    final bytes = <int>[];
    await for (final chunk in res.read()) {
      bytes.addAll(chunk);
    }
    return TestResponse._(res.statusCode, res.headers, bytes);
  }

  Uri _uri(String path, Map<String, Object?>? query) {
    final uri = baseUri.resolve(path.startsWith('/') ? path : '/$path');
    if (query == null || query.isEmpty) return uri;
    final all = <String, List<String>>{
      for (final e in uri.queryParametersAll.entries) e.key: [...e.value],
    };
    for (final e in query.entries) {
      final v = e.value;
      if (v == null) continue;
      all.putIfAbsent(e.key, () => []).addAll(
          v is Iterable ? v.map((x) => '$x') : ['$v']);
    }
    return uri.replace(queryParameters: all);
  }

  static Map<String, String> _lower(Map<String, String> h) =>
      {for (final e in h.entries) e.key.toLowerCase(): e.value};
}

/// A fully read response.
class TestResponse {
  TestResponse._(this.statusCode, Map<String, String> headers, List<int> bytes)
      : headers = UnmodifiableMapView(CaseInsensitiveMap.from(headers)),
        bodyBytes = List.unmodifiable(bytes);

  final int statusCode;

  /// Response headers; lookups ignore case.
  final Map<String, String> headers;

  final List<int> bodyBytes;

  late final String body = utf8.decode(bodyBytes, allowMalformed: true);

  /// The decoded JSON body. Throws [FormatException] (showing the body)
  /// when it isn't JSON.
  late final Object? json = _decode();

  /// [json] as an object.
  Map<String, Object?> get jsonMap {
    final j = json;
    if (j is Map<String, Object?>) return j;
    throw StateError('Expected a JSON object, got: $body');
  }

  /// [json] as an array.
  List<Object?> get jsonList {
    final j = json;
    if (j is List<Object?>) return j;
    throw StateError('Expected a JSON array, got: $body');
  }

  /// The `error` object of gisila's error envelope, or `null`.
  Map<String, Object?>? get error {
    if (body.isEmpty) return null;
    try {
      final j = json;
      final e = j is Map ? j['error'] : null;
      return e is Map<String, Object?> ? e : null;
    } on FormatException {
      return null;
    }
  }

  /// `error.code` (`unauthorized`, `invalid_token`, `validation_error`...).
  String? get errorCode => error?['code'] as String?;

  /// `error.message`.
  String? get errorMessage => error?['message'] as String?;

  Object? _decode() {
    try {
      return jsonDecode(body);
    } on FormatException {
      throw FormatException('Response body is not JSON ($statusCode): $body');
    }
  }

  @override
  String toString() {
    final shown = body.length > 500 ? '${body.substring(0, 500)}...' : body;
    return 'TestResponse($statusCode, $shown)';
  }
}

/// An [Authenticator] for tests: [tokenFor] hands out a token for any
/// [Principal], and the client's [GisilaTestClient.as] uses it. Other
/// requests go to [fallback], so real tokens keep working alongside.
class TestAuthenticator extends Authenticator {
  TestAuthenticator({this.fallback = const NullAuthenticator()});

  final Authenticator fallback;
  final Map<String, Principal> _tokens = <String, Principal>{};
  int _next = 0;

  /// A bearer token that authenticates as [principal].
  String tokenFor(Principal principal) {
    final token = 'gisila-test-${_next++}';
    _tokens[token] = principal;
    return token;
  }

  @override
  Future<Principal?> authenticate(Request request) async {
    final header = request.headers['authorization'];
    if (header != null && header.startsWith('Bearer ')) {
      final p = _tokens[header.substring(7).trim()];
      if (p != null) return p;
    }
    return fallback.authenticate(request);
  }
}
