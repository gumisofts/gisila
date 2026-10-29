import 'package:gisila/gisila.dart';
import 'package:gisila/testing.dart';
import 'package:test/test.dart';

import 'fixtures/guarded_controller.dart';

const _secret = 'a-test-secret-that-is-at-least-32-bytes';

void main() {
  final key = ApiKeyAuthenticator.generate(prefix: 'sk_test_');
  final stored = {
    ApiKeyAuthenticator.hash(key):
        const Principal(id: 'script', permissions: {'write'}),
  };
  final seenHashes = <String>[];
  ApiKeyAuthenticator apiKeys({String header = 'X-API-Key'}) =>
      ApiKeyAuthenticator(
          header: header,
          lookup: (hash, request) {
            seenHashes.add(hash);
            return stored[hash];
          });

  Request req(Map<String, String> headers) =>
      Request('GET', Uri.parse('http://api.test/'), headers: headers);

  Matcher rejected(String code) => throwsA(isA<HttpException>()
      .having((e) => e.statusCode, 'statusCode', 401)
      .having((e) => e.code, 'code', code));

  setUp(seenHashes.clear);

  group('ApiKeyAuthenticator', () {
    test('generate makes distinct prefixed 256-bit keys', () {
      final a = ApiKeyAuthenticator.generate(prefix: 'sk_');
      final b = ApiKeyAuthenticator.generate(prefix: 'sk_');
      expect(a, startsWith('sk_'));
      expect(a, isNot(b));
      expect(a.length, 3 + 43);
      expect(ApiKeyAuthenticator.hash(a), matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    test('looks keys up by hash, never by the key itself', () async {
      final p = await apiKeys().authenticate(req({'x-api-key': key}));
      expect(p!.id, 'script');
      expect(seenHashes, [ApiKeyAuthenticator.hash(key)]);
      expect(seenHashes.single, isNot(contains(key)));
    });

    test('no key is anonymous; unknown or oversized keys are 401', () async {
      final a = apiKeys();
      expect(await a.authenticate(req({})), isNull);
      await expectLater(
          a.authenticate(req({'x-api-key': 'sk_test_nope'})),
          rejected('invalid_api_key'));
      await expectLater(a.authenticate(req({'x-api-key': 'k' * 300})),
          rejected('invalid_api_key'));
      expect(seenHashes, hasLength(1)); // the oversized one wasn't looked up
    });

    test('custom header and keyFromRequest', () async {
      expect(
          await apiKeys(header: 'Api-Token')
              .authenticate(req({'api-token': key})),
          isNotNull);
      final fromQuery = ApiKeyAuthenticator(
          lookup: (hash, _) => stored[hash],
          keyFromRequest: (r) => r.url.queryParameters['key']);
      expect(
          await fromQuery.authenticate(
              Request('GET', Uri.parse('http://api.test/?key=$key'))),
          isNotNull);
    });
  });

  group('CompositeAuthenticator', () {
    final signer = JwtSigner(key: JwtKey.hmac(_secret), algorithm: 'HS256');
    GisilaTestClient client() {
      final app = GisilaApp(
          config: AppConfig(
              logRequests: false,
              authenticator: CompositeAuthenticator([
                JwtAuthenticator(
                    key: JwtKey.hmac(_secret), algorithms: {'HS256'}),
                apiKeys(),
              ])));
      app.registerController(
          attacher: (a, router, {prefix = ''}) =>
              GuardedController().attachToApp(a, router, prefix: prefix));
      return GisilaTestClient(app);
    }

    test('first match wins: JWT or API key', () async {
      final c = client();
      expect(
          (await c.withToken(signer.sign(subject: 'u1')).get('/x/me')).jsonMap,
          {'id': 'u1'});
      expect(
          (await c.withHeaders({'x-api-key': key}).get('/x/me')).jsonMap,
          {'id': 'script'});
      expect((await c.get('/x/me')).statusCode, 401);
    });

    test('a bad credential ends the search', () async {
      final res = await client()
          .withToken('not-a-jwt')
          .withHeaders({'x-api-key': key}).get('/x/me');
      expect(res.statusCode, 401);
      expect(res.errorCode, 'invalid_token');
    });

    test('needs at least one authenticator', () {
      expect(() => CompositeAuthenticator([]), throwsArgumentError);
    });
  });
}
