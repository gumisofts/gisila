import 'package:gisila/gisila.dart';
import 'package:gisila/testing.dart';
import 'package:test/test.dart';

import 'fixtures/guarded_controller.dart';

const _secret = 'a-test-secret-that-is-at-least-32-bytes';

GisilaApp _app(Authenticator authenticator) {
  final app = GisilaApp(
      config: AppConfig(logRequests: false, authenticator: authenticator));
  app.registerController(
      attacher: (a, router, {prefix = ''}) =>
          GuardedController().attachToApp(a, router, prefix: prefix));
  return app;
}

void main() {
  group('GisilaTestClient', () {
    late GisilaTestClient client;
    const writer = Principal(id: 'w1', permissions: {'write'});

    setUp(() => client = GisilaTestClient(_app(TestAuthenticator())));

    test('sends requests through the full pipeline', () async {
      final res = await client.get('/x/public');
      expect(res.statusCode, 200);
      expect(res.jsonMap, {'ok': true});
      expect(res.headers['content-type'], contains('application/json'));
    });

    test('exposes the error envelope', () async {
      final res = await client.get('/x/me');
      expect(res.statusCode, 401);
      expect(res.errorCode, 'unauthorized');
      expect(res.errorMessage, isNotEmpty);
    });

    test('as() authenticates without touching the shared client', () async {
      final me = await client.as(writer).get('/x/me');
      expect(me.jsonMap, {'id': 'w1'});
      expect((await client.get('/x/me')).statusCode, 401);
    });

    test('json and form bodies reach typed forms', () async {
      final asWriter = client.as(writer);
      final viaJson =
          await asWriter.post('/x/notes', json: {'title': 'a', 'stars': 3});
      expect(viaJson.statusCode, 201);
      expect(viaJson.jsonMap, {'title': 'a', 'stars': 3});
      final viaForm =
          await asWriter.post('/x/notes', form: {'title': 'b', 'stars': '2'});
      expect(viaForm.jsonMap, {'title': 'b', 'stars': 2});
      final invalid = await asWriter.post('/x/notes', json: {'stars': 9});
      expect(invalid.statusCode, 400);
      expect(invalid.error, isNotNull);
    });

    test('guards answer 403 for the wrong principal', () async {
      final res = await client
          .as(const Principal(id: 'r'))
          .post('/x/notes', json: {'title': 'a'});
      expect(res.statusCode, 403);
      expect(res.errorCode, 'forbidden');
    });

    test('query maps merge with the path query, lists repeat', () async {
      final res = await client.get('/x/items/4?page=1', query: {'page': 2});
      expect(res.statusCode, 200);
      expect(res.jsonMap['id'], 4);
    });

    test('withHeaders adds headers; per-request headers win', () async {
      final c = client.withHeaders({'X-Request-Id': 'abc'});
      expect((await c.get('/x/public')).headers['x-request-id'], 'abc');
      final res =
          await c.get('/x/public', headers: {'x-request-id': 'override'});
      expect(res.headers['x-request-id'], 'override');
    });

    test('only one body kind at a time', () {
      expect(() => client.post('/x/notes', json: {}, form: {}),
          throwsArgumentError);
    });

    test('as() explains when the app has another authenticator', () {
      final other = GisilaTestClient(_app(const NullAuthenticator()));
      expect(() => other.as(writer), throwsStateError);
    });

    test('non-JSON bodies fail clearly', () async {
      final res = await GisilaTestClient.handler(
          (_) => Response.ok('plain')).get('/');
      expect(res.body, 'plain');
      expect(() => res.json, throwsFormatException);
      expect(res.error, isNull);
    });

    test('TestAuthenticator falls back for other tokens', () async {
      final c = GisilaTestClient(_app(TestAuthenticator(
          fallback: const StaticTokenAuthenticator(
              {'real': Principal(id: 'from-fallback')}))));
      expect((await c.withToken('real').get('/x/me')).jsonMap,
          {'id': 'from-fallback'});
    });
  });

  group('JwtAuthenticator through the app', () {
    final signer = JwtSigner(key: JwtKey.hmac(_secret), algorithm: 'HS256');
    late GisilaTestClient client;

    setUp(() => client = GisilaTestClient(_app(JwtAuthenticator(
        key: JwtKey.hmac(_secret), algorithms: {'HS256'}))));

    test('a valid token reaches the handler', () async {
      final res =
          await client.withToken(signer.sign(subject: 'u1')).get('/x/me');
      expect(res.jsonMap, {'id': 'u1'});
    });

    test('scope claims satisfy @Permissions', () async {
      final token = signer.sign(subject: 'u1', claims: {'scope': 'write'});
      final res = await client
          .withToken(token)
          .post('/x/notes', json: {'title': 'hi'});
      expect(res.statusCode, 201);
    });

    test('bad and expired tokens get distinct 401 codes', () async {
      final bad = await client.withToken('nope').get('/x/me');
      expect(bad.statusCode, 401);
      expect(bad.errorCode, 'invalid_token');
      final expired = await client
          .withToken(signer.sign(
              subject: 'u1', expiresIn: const Duration(minutes: -5)))
          .get('/x/me');
      expect(expired.statusCode, 401);
      expect(expired.errorCode, 'token_expired');
    });

    test('public routes ignore a bad token', () async {
      expect((await client.withToken('nope').get('/x/public')).statusCode, 200);
    });
  });
}
