import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart' as jose;
import 'package:gisila/gisila.dart';
import 'package:test/test.dart';

import 'fixtures/jwt_keys.dart';

final _now = DateTime.utc(2026, 10, 29, 12);
DateTime _clock() => _now;

const _secret = 'a-test-secret-that-is-at-least-32-bytes';

Request _req(String? token, {String scheme = 'Bearer'}) =>
    Request('GET', Uri.parse('http://api.test/'),
        headers: {if (token != null) 'authorization': '$scheme $token'});

/// Signs [payload] as-is with an HMAC key, whatever [header] claims.
String _forge(Map<String, Object?> header, Map<String, Object?> payload,
        {String secret = _secret}) =>
    jose.JWT(payload, header: header)
        .sign(jose.SecretKey(secret), noIssueAt: true);

int _ts(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

Matcher _rejected(String code) => throwsA(isA<HttpException>()
    .having((e) => e.statusCode, 'statusCode', 401)
    .having((e) => e.code, 'code', code));

void main() {
  late JwtSigner signer;
  late JwtAuthenticator auth;

  setUp(() {
    signer = JwtSigner(
        key: JwtKey.hmac(_secret),
        algorithm: 'HS256',
        issuer: 'gisila-test',
        audience: 'api',
        now: _clock);
    auth = JwtAuthenticator(
        key: JwtKey.hmac(_secret),
        algorithms: {'HS256'},
        issuer: 'gisila-test',
        audience: {'api', 'other'},
        now: _clock);
  });

  group('JwtAuthenticator', () {
    test('maps sub, roles, scope and permissions to the principal', () async {
      final token = signer.sign(subject: 'u1', claims: {
        'roles': ['admin'],
        'scope': 'notes:read notes:write',
        'permissions': ['billing'],
        'tenant': 't9',
      });
      final p = (await auth.authenticate(_req(token)))!;
      expect(p.id, 'u1');
      expect(p.roles, {'admin'});
      expect(p.permissions, {'notes:read', 'notes:write', 'billing'});
      expect(p.claims['tenant'], 't9');
    });

    test('no credentials, or another scheme, is anonymous', () async {
      expect(await auth.authenticate(_req(null)), isNull);
      expect(await auth.authenticate(_req('abc', scheme: 'Basic')), isNull);
    });

    test('the scheme is case-insensitive', () async {
      final token = signer.sign(subject: 'u1');
      expect(await auth.authenticate(_req(token, scheme: 'bearer')), isNotNull);
    });

    test('garbage tokens are invalid, not 500s', () async {
      for (final t in ['abc', 'a.b.c', '!!.??.**', '${signer.sign()}x']) {
        await expectLater(auth.authenticate(_req(t)), _rejected('invalid_token'),
            reason: t);
      }
    });

    test('a token signed with another secret is invalid', () async {
      final other = JwtSigner(
          key: JwtKey.hmac('another-secret-also-at-least-32-bytes!'),
          algorithm: 'HS256',
          issuer: 'gisila-test',
          audience: 'api',
          now: _clock);
      await expectLater(auth.authenticate(_req(other.sign(subject: 'u1'))),
          _rejected('invalid_token'));
    });

    test('expiry is enforced with leeway', () async {
      final expired = signer.sign(
          subject: 'u1', expiresIn: const Duration(seconds: -31));
      await expectLater(
          auth.authenticate(_req(expired)), _rejected('token_expired'));
      final justExpired = signer.sign(
          subject: 'u1', expiresIn: const Duration(seconds: -29));
      expect(await auth.authenticate(_req(justExpired)), isNotNull);
    });

    test('a token without exp is refused unless requireExpiry is off',
        () async {
      final token = _forge({'alg': 'HS256'},
          {'sub': 'u1', 'iss': 'gisila-test', 'aud': 'api'});
      await expectLater(
          auth.authenticate(_req(token)), _rejected('invalid_token'));
      final lax = JwtAuthenticator(
          key: JwtKey.hmac(_secret),
          algorithms: {'HS256'},
          requireExpiry: false,
          now: _clock);
      expect(await lax.authenticate(_req(token)), isNotNull);
    });

    test('nbf in the future and non-numeric times are invalid', () async {
      final base = {
        'sub': 'u1',
        'iss': 'gisila-test',
        'aud': 'api',
        'exp': _ts(_now) + 600,
      };
      for (final extra in [
        {'nbf': _ts(_now) + 120},
        {'iat': _ts(_now) + 120},
        {'exp': '9999999999'},
      ]) {
        final token = _forge({'alg': 'HS256'}, {...base, ...extra});
        await expectLater(
            auth.authenticate(_req(token)), _rejected('invalid_token'),
            reason: '$extra');
      }
    });

    test('maxAge needs a recent iat', () async {
      final strict = JwtAuthenticator(
          key: JwtKey.hmac(_secret),
          algorithms: {'HS256'},
          maxAge: const Duration(minutes: 5),
          now: _clock);
      final fresh = _forge({'alg': 'HS256'},
          {'sub': 'u1', 'iat': _ts(_now) - 60, 'exp': _ts(_now) + 3600});
      final old = _forge({'alg': 'HS256'},
          {'sub': 'u1', 'iat': _ts(_now) - 3600, 'exp': _ts(_now) + 3600});
      final none =
          _forge({'alg': 'HS256'}, {'sub': 'u1', 'exp': _ts(_now) + 3600});
      expect(await strict.authenticate(_req(fresh)), isNotNull);
      await expectLater(
          strict.authenticate(_req(old)), _rejected('token_expired'));
      await expectLater(
          strict.authenticate(_req(none)), _rejected('invalid_token'));
    });

    test('issuer must match and audience must overlap', () async {
      final otherIssuer = JwtSigner(
          key: JwtKey.hmac(_secret),
          algorithm: 'HS256',
          issuer: 'someone-else',
          audience: 'api',
          now: _clock);
      await expectLater(auth.authenticate(_req(otherIssuer.sign(subject: 'u'))),
          _rejected('invalid_token'));

      final exp = _ts(_now) + 600;
      final multi = _forge({'alg': 'HS256'}, {
        'sub': 'u1',
        'iss': 'gisila-test',
        'aud': ['third-party', 'other'],
        'exp': exp,
      });
      expect(await auth.authenticate(_req(multi)), isNotNull);
      final wrong = _forge({'alg': 'HS256'},
          {'sub': 'u1', 'iss': 'gisila-test', 'aud': 'nope', 'exp': exp});
      await expectLater(
          auth.authenticate(_req(wrong)), _rejected('invalid_token'));
    });

    test('an algorithm outside the allowlist is refused', () async {
      final payload = {
        'sub': 'u1',
        'iss': 'gisila-test',
        'aud': 'api',
        'exp': _ts(_now) + 600,
      };
      final hs384 = jose.JWT(payload)
          .sign(jose.SecretKey(_secret), algorithm: jose.JWTAlgorithm.HS384);
      await expectLater(
          auth.authenticate(_req(hs384)), _rejected('invalid_token'));

      String b64(Object o) =>
          base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
      final unsigned = '${b64({'alg': 'none', 'typ': 'JWT'})}.${b64(payload)}.';
      await expectLater(
          auth.authenticate(_req(unsigned)), _rejected('invalid_token'));
    });

    test('an RSA public key used as an HMAC secret is refused', () async {
      final rsa = JwtAuthenticator(
          key: JwtKey.rsaPublicPem(rsaPublicPem),
          algorithms: {'RS256'},
          now: _clock);
      final forged = _forge({'alg': 'HS256'},
          {'sub': 'admin', 'exp': _ts(_now) + 600},
          secret: rsaPublicPem);
      await expectLater(
          rsa.authenticate(_req(forged)), _rejected('invalid_token'));
      expect(
          () => JwtAuthenticator(
              key: JwtKey.rsaPublicPem(rsaPublicPem), algorithms: {'HS256'}),
          throwsArgumentError);
    });

    test('RS256 and ES256 round-trip', () async {
      for (final (priv, pub, alg) in [
        (JwtKey.rsaPrivatePem(rsaPrivatePem),
            JwtKey.rsaPublicPem(rsaPublicPem), 'RS256'),
        (JwtKey.ecPrivatePem(ecPrivatePem), JwtKey.ecPublicPem(ecPublicPem),
            'ES256'),
      ]) {
        final token = JwtSigner(key: priv, algorithm: alg, now: _clock)
            .sign(subject: 'u1');
        final verifier =
            JwtAuthenticator(key: pub, algorithms: {alg}, now: _clock);
        expect((await verifier.authenticate(_req(token)))!.id, 'u1',
            reason: alg);
      }
    });

    test('requiredType checks the header typ', () async {
      final typed = JwtAuthenticator(
          key: JwtKey.hmac(_secret),
          algorithms: {'HS256'},
          requiredType: 'at+jwt',
          now: _clock);
      final exp = _ts(_now) + 600;
      final ok = _forge({'alg': 'HS256', 'typ': 'at+JWT'},
          {'sub': 'u1', 'exp': exp});
      final idToken =
          _forge({'alg': 'HS256', 'typ': 'JWT'}, {'sub': 'u1', 'exp': exp});
      expect(await typed.authenticate(_req(ok)), isNotNull);
      await expectLater(
          typed.authenticate(_req(idToken)), _rejected('invalid_token'));
    });

    test('toPrincipal sees the claims and request; null rejects', () async {
      Request? seen;
      final custom = JwtAuthenticator(
          key: JwtKey.hmac(_secret),
          algorithms: {'HS256'},
          now: _clock,
          toPrincipal: (claims, request) {
            seen = request;
            return claims.subject == 'deleted'
                ? null
                : Principal(id: 'user-${claims.subject}');
          });
      final s = JwtSigner(
          key: JwtKey.hmac(_secret), algorithm: 'HS256', now: _clock);
      final req = _req(s.sign(subject: '7'));
      expect((await custom.authenticate(req))!.id, 'user-7');
      expect(seen, same(req));
      await expectLater(custom.authenticate(_req(s.sign(subject: 'deleted'))),
          _rejected('invalid_token'));
    });

    test('tokenFromRequest reads tokens from elsewhere', () async {
      final cookie = JwtAuthenticator(
          key: JwtKey.hmac(_secret),
          algorithms: {'HS256'},
          now: _clock,
          tokenFromRequest: (r) => r.headers['x-token']);
      final s = JwtSigner(
          key: JwtKey.hmac(_secret), algorithm: 'HS256', now: _clock);
      final req = Request('GET', Uri.parse('http://api.test/'),
          headers: {'x-token': s.sign(subject: 'u1')});
      expect(await cookie.authenticate(req), isNotNull);
    });

    test('constructor refuses bad configurations', () {
      final key = JwtKey.hmac(_secret);
      expect(() => JwtAuthenticator(algorithms: {'HS256'}), throwsArgumentError);
      expect(() => JwtAuthenticator(key: key, algorithms: {}),
          throwsArgumentError);
      expect(() => JwtAuthenticator(key: key, algorithms: {'none'}),
          throwsArgumentError);
      expect(
          () => JwtAuthenticator(
              key: JwtKey.rsaPrivatePem(rsaPrivatePem), algorithms: {'RS256'}),
          throwsArgumentError);
    });
  });

  group('JwtKey and JwtSigner', () {
    test('short HMAC secrets are refused', () {
      expect(() => JwtKey.hmac('short'), throwsArgumentError);
      expect(
          () => JwtKey.fromJwk({
                'kty': 'oct',
                'k': base64Url.encode(utf8.encode('short')),
              }),
          throwsArgumentError);
    });

    test('a JWK alg that does not fit its kty is refused', () {
      final jwk = jose.RSAPublicKey(rsaPublicPem).toJWK(keyID: 'k1');
      expect(() => JwtKey.fromJwk({...jwk, 'alg': 'HS256'}),
          throwsArgumentError);
      expect(JwtKey.fromJwk({...jwk, 'alg': 'RS256'}).id, 'k1');
    });

    test('signing needs a private key and a fitting algorithm', () {
      expect(
          () => JwtSigner(
              key: JwtKey.rsaPublicPem(rsaPublicPem), algorithm: 'RS256'),
          throwsArgumentError);
      expect(() => JwtSigner(key: JwtKey.hmac(_secret), algorithm: 'RS256'),
          throwsArgumentError);
    });

    test('claims cannot overwrite the registered ones', () {
      final token = signer.sign(
          subject: 'u1', claims: {'sub': 'admin', 'exp': 9999999999});
      final claims = jose.JWT.decode(token).payload as Map;
      expect(claims['sub'], 'u1');
      expect(claims['exp'], _ts(_now) + 3600);
      expect(claims['iat'], _ts(_now));
    });

    test('kid goes into the header', () {
      final token = JwtSigner(
              key: JwtKey.hmac(_secret, id: 'k2'), algorithm: 'HS256')
          .sign();
      expect(jose.JWT.decode(token).header!['kid'], 'k2');
    });
  });

  group('key sets', () {
    final k1 = JwtKey.hmac('${_secret}1', id: 'k1');
    final k2 = JwtKey.hmac('${_secret}2', id: 'k2');

    test('StaticJwtKeySet picks the key by kid', () async {
      final a = JwtAuthenticator(
          keys: StaticJwtKeySet([k1, k2]), algorithms: {'HS256'}, now: _clock);
      for (final k in [k1, k2]) {
        final t = JwtSigner(key: k, algorithm: 'HS256', now: _clock)
            .sign(subject: k.id);
        expect((await a.authenticate(_req(t)))!.id, k.id);
      }
      // Without a kid there's no telling which key to use.
      final noKid = JwtSigner(
              key: JwtKey.hmac('${_secret}1'), algorithm: 'HS256', now: _clock)
          .sign(subject: 'u');
      await expectLater(a.authenticate(_req(noKid)), _rejected('invalid_token'));
    });

    test('a key never verifies an algorithm it does not fit', () async {
      final a = JwtAuthenticator(
          keys: StaticJwtKeySet([JwtKey.rsaPublicPem(rsaPublicPem, id: 'r')]),
          algorithms: {'HS256', 'RS256'},
          now: _clock);
      final forged = _forge({'alg': 'HS256', 'kid': 'r'},
          {'sub': 'admin', 'exp': _ts(_now) + 600},
          secret: rsaPublicPem);
      await expectLater(a.authenticate(_req(forged)), _rejected('invalid_token'));
    });

    group('RemoteJwks', () {
      final rsaJwk = jose.RSAPublicKey(rsaPublicPem).toJWK(keyID: 'r1');
      final ecJwk = jose.ECPublicKey(ecPublicPem).toJWK(keyID: 'e1');
      final rsaToken = JwtSigner(
              key: JwtKey.rsaPrivatePem(rsaPrivatePem, id: 'r1'),
              algorithm: 'RS256',
              now: _clock)
          .sign(subject: 'u1');
      final ecToken = JwtSigner(
              key: JwtKey.ecPrivatePem(ecPrivatePem, id: 'e1'),
              algorithm: 'ES256',
              now: _clock)
          .sign(subject: 'u2');

      late DateTime clock;
      late List<Map<String, Object?>> published;
      late int fetches;
      late bool failing;
      late JwtAuthenticator a;

      setUp(() {
        clock = _now;
        published = [rsaJwk];
        fetches = 0;
        failing = false;
        final jwks = RemoteJwks(Uri.parse('https://idp.test/jwks.json'),
            now: () => clock, fetch: (url) async {
          fetches++;
          if (failing) throw StateError('down');
          return jsonEncode({
            'keys': [
              {'kty': 'oct', 'k': base64Url.encode(utf8.encode(_secret))},
              {...ecJwk, 'kid': 'enc', 'use': 'enc'},
              ...published,
            ]
          });
        });
        a = JwtAuthenticator(
            keys: jwks, algorithms: {'RS256', 'ES256', 'HS256'}, now: () => clock);
      });

      test('loads once and serves from cache', () async {
        expect((await a.authenticate(_req(rsaToken)))!.id, 'u1');
        expect((await a.authenticate(_req(rsaToken)))!.id, 'u1');
        expect(fetches, 1);
      });

      test('ignores published symmetric keys', () async {
        final hs = _forge({'alg': 'HS256'}, {'sub': 'x', 'exp': _ts(_now) + 60});
        await expectLater(a.authenticate(_req(hs)), _rejected('invalid_token'));
      });

      test('an unknown kid refreshes early, but not more than once per '
          'minRefreshInterval', () async {
        await a.authenticate(_req(rsaToken));
        published = [rsaJwk, ecJwk];
        clock = clock.add(const Duration(seconds: 5));
        await expectLater(a.authenticate(_req(ecToken)), _rejected('invalid_token'));
        expect(fetches, 1);
        clock = clock.add(const Duration(seconds: 30));
        expect((await a.authenticate(_req(ecToken)))!.id, 'u2');
        expect(fetches, 2);
      });

      test('keeps the old keys when a refresh fails', () async {
        await a.authenticate(_req(rsaToken));
        failing = true;
        clock = clock.add(const Duration(minutes: 11));
        expect((await a.authenticate(_req(rsaToken)))!.id, 'u1');
        expect(fetches, 2);
      });

      test('fails when no keys could ever be loaded, retrying at most once '
          'per minRefreshInterval', () async {
        failing = true;
        await expectLater(a.authenticate(_req(rsaToken)), throwsStateError);
        await expectLater(a.authenticate(_req(rsaToken)), throwsStateError);
        expect(fetches, 1);
        failing = false;
        clock = clock.add(const Duration(seconds: 31));
        expect((await a.authenticate(_req(rsaToken)))!.id, 'u1');
        expect(fetches, 2);
      });

      test('refuses plain http except on loopback', () {
        expect(() => RemoteJwks(Uri.parse('http://idp.test/jwks')),
            throwsArgumentError);
        RemoteJwks(Uri.parse('http://localhost:8080/jwks'));
        RemoteJwks(Uri.parse('http://127.0.0.1/jwks'));
      });
    });
  });
}
