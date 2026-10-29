/// JSON Web Token authentication: [JwtAuthenticator] verifies bearer tokens,
/// [JwtSigner] issues them, and [JwtKey] / [JwtKeySet] / [RemoteJwks] supply
/// the keys.
///
/// Signatures are checked by `package:dart_jsonwebtoken`. Everything around
/// the signature (which algorithms are allowed, which key may verify which
/// algorithm, `exp` / `nbf` / `iat` with clock leeway, issuer and audience)
/// is checked here, so a token can't pick its own algorithm or skip expiry.
library gisila.runtime.auth.jwt;

import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpClient, InternetAddress;

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart' as jose;
import 'package:shelf/shelf.dart';

import '../exceptions.dart';
import 'authenticator.dart';
import 'principal.dart';

/// Shortest HMAC secret [JwtKey.hmac] accepts, in bytes (RFC 7518 §3.2 asks
/// for at least the hash size; 32 bytes covers HS256).
const int minJwtHmacSecretBytes = 32;

/// Algorithm names [JwtAuthenticator] and [JwtSigner] accept.
const Set<String> supportedJwtAlgorithms = <String>{
  'HS256', 'HS384', 'HS512', //
  'RS256', 'RS384', 'RS512', //
  'PS256', 'PS384', 'PS512', //
  'ES256', 'ES384', 'ES512', 'ES256K', //
  'EdDSA',
};

enum _KeyFamily { hmac, rsa, ec, eddsa }

_KeyFamily _familyOf(String algorithm) {
  if (algorithm.startsWith('HS')) return _KeyFamily.hmac;
  if (algorithm.startsWith('RS') || algorithm.startsWith('PS')) {
    return _KeyFamily.rsa;
  }
  if (algorithm.startsWith('ES')) return _KeyFamily.ec;
  return _KeyFamily.eddsa;
}

/// A key that signs or verifies tokens.
///
/// An HMAC key does both. For RSA, EC and EdDSA, the public key verifies
/// (give it to [JwtAuthenticator]) and the private key signs (give it to
/// [JwtSigner]).
class JwtKey {
  JwtKey._(this._key, this._family,
      {required this.isPrivate, this.id, this.algorithm});

  /// An HMAC secret (HS256/384/512). Throws [ArgumentError] when it is
  /// shorter than [minJwtHmacSecretBytes] bytes: short secrets can be
  /// brute-forced from any token.
  factory JwtKey.hmac(String secret, {String? id}) {
    if (utf8.encode(secret).length < minJwtHmacSecretBytes) {
      throw ArgumentError.value('<redacted>', 'secret',
          'must be at least $minJwtHmacSecretBytes bytes');
    }
    return JwtKey._(jose.SecretKey(secret), _KeyFamily.hmac,
        isPrivate: false, id: id);
  }

  /// An RSA public key (`-----BEGIN PUBLIC KEY-----` or an X.509
  /// certificate) for RS* / PS* verification.
  factory JwtKey.rsaPublicPem(String pem, {String? id}) => JwtKey._(
      pem.contains('CERTIFICATE')
          ? jose.RSAPublicKey.cert(pem)
          : jose.RSAPublicKey(pem),
      _KeyFamily.rsa,
      isPrivate: false,
      id: id);

  /// An RSA private key for RS* / PS* signing.
  factory JwtKey.rsaPrivatePem(String pem, {String? id}) =>
      JwtKey._(jose.RSAPrivateKey(pem), _KeyFamily.rsa,
          isPrivate: true, id: id);

  /// An EC public key (`-----BEGIN PUBLIC KEY-----` or an X.509
  /// certificate) for ES* verification.
  factory JwtKey.ecPublicPem(String pem, {String? id}) => JwtKey._(
      pem.contains('CERTIFICATE')
          ? jose.ECPublicKey.cert(pem)
          : jose.ECPublicKey(pem),
      _KeyFamily.ec,
      isPrivate: false,
      id: id);

  /// An EC private key for ES* signing.
  factory JwtKey.ecPrivatePem(String pem, {String? id}) =>
      JwtKey._(jose.ECPrivateKey(pem), _KeyFamily.ec,
          isPrivate: true, id: id);

  /// A key in JWK form (RFC 7517). Its `kid` and `alg`, when present,
  /// become [id] and [algorithm].
  factory JwtKey.fromJwk(Map<String, Object?> jwk) {
    final kty = jwk['kty'];
    final _KeyFamily family;
    final bool isPrivate;
    switch (kty) {
      case 'oct':
        final k = jwk['k'];
        if (k is! String ||
            base64Url.decode(base64Url.normalize(k)).length <
                minJwtHmacSecretBytes) {
          throw ArgumentError.value('<redacted>', 'jwk',
              'oct key must be at least $minJwtHmacSecretBytes bytes');
        }
        family = _KeyFamily.hmac;
        isPrivate = false;
      case 'RSA':
        family = _KeyFamily.rsa;
        isPrivate = jwk['d'] != null;
      case 'EC':
        family = _KeyFamily.ec;
        isPrivate = jwk['d'] != null;
      case 'OKP':
        family = _KeyFamily.eddsa;
        isPrivate = jwk['d'] != null;
      default:
        throw ArgumentError.value(kty, 'jwk', 'unsupported "kty"');
    }
    final alg = jwk['alg'];
    if (alg != null &&
        (alg is! String ||
            !supportedJwtAlgorithms.contains(alg) ||
            _familyOf(alg) != family)) {
      throw ArgumentError.value(alg, 'jwk', '"alg" does not fit "kty" $kty');
    }
    return JwtKey._(
      jose.JWTKey.fromJWK(Map<String, dynamic>.from(jwk)),
      family,
      isPrivate: isPrivate,
      id: jwk['kid'] as String?,
      algorithm: alg as String?,
    );
  }

  final jose.JWTKey _key;
  final _KeyFamily _family;

  /// `true` for RSA / EC / EdDSA private keys, which sign but don't verify.
  final bool isPrivate;

  /// Key id, matched against the token header's `kid`.
  final String? id;

  /// When set, the only algorithm this key is used with.
  final String? algorithm;

  bool get _canVerify => !isPrivate;
  bool get _canSign => _family == _KeyFamily.hmac || isPrivate;

  bool _fits(String alg) =>
      _familyOf(alg) == _family && (algorithm == null || algorithm == alg);
}

/// Where [JwtAuthenticator] finds the key for a token.
abstract class JwtKeySet {
  const JwtKeySet();

  /// The key for a token whose header carries [kid] (often `null`), or
  /// `null` when there is none.
  Future<JwtKey?> find(String? kid);
}

/// A fixed list of keys, for rotation: keep the old key here until the
/// tokens it signed have expired.
class StaticJwtKeySet extends JwtKeySet {
  StaticJwtKeySet(Iterable<JwtKey> keys) : _keys = List.unmodifiable(keys) {
    if (_keys.isEmpty) throw ArgumentError.value(keys, 'keys', 'is empty');
  }

  final List<JwtKey> _keys;

  @override
  Future<JwtKey?> find(String? kid) async => _match(_keys, kid);
}

/// Without a `kid`, a token is only matched when there is one key, so a
/// token can't be tried against each key in turn.
JwtKey? _match(List<JwtKey> keys, String? kid) {
  if (kid == null) return keys.length == 1 ? keys.single : null;
  for (final k in keys) {
    if (k.id == kid) return k;
  }
  return null;
}

/// Keys published as a JWKS document (an identity provider's
/// `.../.well-known/jwks.json`).
///
/// The document is cached for [cacheFor]. A token with an unknown `kid`
/// triggers an early refresh (the provider rotated keys), at most once per
/// [minRefreshInterval]. When a refresh fails, the keys already loaded keep
/// being used; with none loaded, authentication fails with a 401.
class RemoteJwks extends JwtKeySet {
  /// [url] must be `https`, except on a loopback host. Pass [fetch] to load
  /// the document some other way (tests, a proxy).
  RemoteJwks(
    this.url, {
    this.cacheFor = const Duration(minutes: 10),
    this.minRefreshInterval = const Duration(seconds: 30),
    this.timeout = const Duration(seconds: 5),
    Future<String> Function(Uri url)? fetch,
    DateTime Function()? now,
  })  : _fetch = fetch,
        _now = now ?? DateTime.now {
    final loopback = url.host == 'localhost' ||
        (InternetAddress.tryParse(url.host)?.isLoopback ?? false);
    if (url.scheme != 'https' && !(url.scheme == 'http' && loopback)) {
      throw ArgumentError.value(
          url, 'url', 'must be https (http only on localhost)');
    }
  }

  /// Largest JWKS document accepted.
  static const int maxDocumentBytes = 256 * 1024;

  final Uri url;
  final Duration cacheFor;
  final Duration minRefreshInterval;
  final Duration timeout;
  final Future<String> Function(Uri url)? _fetch;
  final DateTime Function() _now;

  List<JwtKey> _keys = const <JwtKey>[];
  DateTime? _loadedAt;
  DateTime? _lastAttempt;
  Future<void>? _inFlight;

  @override
  Future<JwtKey?> find(String? kid) async {
    final loadedAt = _loadedAt;
    if (loadedAt == null || _now().difference(loadedAt) > cacheFor) {
      await _refresh();
      // Still nothing: the last attempt failed less than
      // minRefreshInterval ago, so don't call the provider again yet.
      if (_loadedAt == null) throw StateError('JWKS from $url is unavailable');
    }
    var key = _match(_keys, kid);
    if (key == null) {
      await _refresh();
      key = _match(_keys, kid);
    }
    return key;
  }

  Future<void> _refresh() {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    final last = _lastAttempt;
    if (last != null && _now().difference(last) < minRefreshInterval) {
      return Future<void>.value();
    }
    _lastAttempt = _now();
    return _inFlight = _load().whenComplete(() => _inFlight = null);
  }

  Future<void> _load() async {
    try {
      final body = await (_fetch ?? _httpGet)(url).timeout(timeout);
      final doc = jsonDecode(body);
      final raw = doc is Map ? doc['keys'] : null;
      if (raw is! List) throw const FormatException('no "keys" list');
      final keys = <JwtKey>[];
      for (final jwk in raw.whereType<Map>()) {
        final use = jwk['use'];
        if (use != null && use != 'sig') continue;
        try {
          final key = JwtKey.fromJwk(Map<String, Object?>.from(jwk));
          // Remote symmetric keys and private keys are never trusted.
          if (key._family != _KeyFamily.hmac && key._canVerify) keys.add(key);
        } catch (_) {
          // Skip keys of kinds this server can't use.
        }
      }
      _keys = List.unmodifiable(keys);
      _loadedAt = _now();
    } catch (_) {
      if (_loadedAt == null) rethrow;
    }
  }

  Future<String> _httpGet(Uri url) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final req = await client.getUrl(url);
      req.followRedirects = false;
      final res = await req.close();
      if (res.statusCode != 200) {
        throw StateError('JWKS fetch from $url: ${res.statusCode}');
      }
      final bytes = <int>[];
      await for (final chunk in res) {
        bytes.addAll(chunk);
        if (bytes.length > maxDocumentBytes) {
          throw StateError('JWKS document from $url is too large');
        }
      }
      return utf8.decode(bytes);
    } finally {
      client.close(force: true);
    }
  }
}

/// The verified contents of a token, handed to
/// [JwtAuthenticator.toPrincipal].
class JwtClaims {
  JwtClaims(Map<String, Object?> claims,
      {Map<String, Object?> header = const <String, Object?>{}})
      : _claims = Map.unmodifiable(claims),
        header = Map.unmodifiable(header);

  final Map<String, Object?> _claims;

  /// The token header (`alg`, `kid`, `typ`, ...).
  final Map<String, Object?> header;

  Object? operator [](String name) => _claims[name];

  bool containsKey(String name) => _claims.containsKey(name);

  Map<String, Object?> toMap() => _claims;

  /// `sub`; a numeric subject is returned as its string form.
  String? get subject => _string(_claims['sub']);

  String? get issuer => _string(_claims['iss']);

  /// `jti`.
  String? get id => _string(_claims['jti']);

  /// `aud`, which may be one string or a list.
  List<String> get audience {
    final aud = _claims['aud'];
    if (aud is String) return <String>[aud];
    if (aud is List) return aud.whereType<String>().toList();
    return const <String>[];
  }

  DateTime? get expiresAt => _time(_claims['exp']);
  DateTime? get issuedAt => _time(_claims['iat']);
  DateTime? get notBefore => _time(_claims['nbf']);

  /// A claim holding a list of strings, or one space-separated string
  /// (the OAuth `scope` form). Empty when absent.
  Set<String> strings(String name) {
    final v = _claims[name];
    if (v is String) return v.split(' ').where((s) => s.isNotEmpty).toSet();
    if (v is List) return v.whereType<String>().toSet();
    return const <String>{};
  }

  static String? _string(Object? v) =>
      v is String ? v : (v is num ? v.toString() : null);

  static DateTime? _time(Object? v) => v is num
      ? DateTime.fromMillisecondsSinceEpoch((v * 1000).round(), isUtc: true)
      : null;
}

/// Turns verified claims into the request's [Principal]. Return `null` to
/// reject the token (the user was deleted or disabled, say).
typedef JwtPrincipalMapper = FutureOr<Principal?> Function(
    JwtClaims claims, Request request);

/// Verifies `Authorization: Bearer <jwt>` and maps the claims to a
/// [Principal].
///
/// ```dart
/// authenticator: JwtAuthenticator(
///   key: JwtKey.hmac(env['JWT_SECRET']!),
///   algorithms: {'HS256'},
///   issuer: 'my-app',
///   toPrincipal: (claims, request) async {
///     final user = await users.find(claims.subject);
///     return user == null ? null : Principal(id: '${user.id}', claims: {'user': user});
///   },
/// ),
/// ```
///
/// A request without a bearer token is anonymous (`null`). A token that
/// fails any check is answered with a 401 whose error code is
/// `token_expired` or `invalid_token`, so clients know when to refresh.
class JwtAuthenticator extends Authenticator {
  /// Give exactly one of [key] and [keys]. Every algorithm in [algorithms]
  /// must fit the key's type: an RSA key with `{'HS256'}` is refused, which
  /// shuts out tokens signed with the public key as an HMAC secret.
  ///
  /// [audience] passes when the token's `aud` holds any of its values.
  /// Without [toPrincipal], `sub` becomes the id, the `roles` claim the
  /// roles, and `scope` plus `permissions` the permissions.
  JwtAuthenticator({
    JwtKey? key,
    JwtKeySet? keys,
    required Set<String> algorithms,
    this.issuer,
    Set<String> audience = const <String>{},
    this.leeway = const Duration(seconds: 30),
    this.requireExpiry = true,
    this.maxAge,
    this.requiredType,
    this.scheme = 'Bearer',
    String? Function(Request request)? tokenFromRequest,
    JwtPrincipalMapper? toPrincipal,
    DateTime Function()? now,
  })  : algorithms = Set.unmodifiable(algorithms),
        audience = Set.unmodifiable(audience),
        _keys = keys ?? (key == null ? null : StaticJwtKeySet([key])),
        _tokenFromRequest = tokenFromRequest,
        _toPrincipal = toPrincipal ?? defaultPrincipal,
        _now = now ?? DateTime.now {
    if ((key == null) == (keys == null)) {
      throw ArgumentError('Give exactly one of `key` and `keys`.');
    }
    if (algorithms.isEmpty) {
      throw ArgumentError.value(algorithms, 'algorithms', 'is empty');
    }
    for (final alg in algorithms) {
      if (!supportedJwtAlgorithms.contains(alg)) {
        throw ArgumentError.value(alg, 'algorithms', 'is not supported');
      }
      if (key != null && !key._fits(alg)) {
        throw ArgumentError.value(alg, 'algorithms', 'does not fit the key');
      }
    }
    if (key != null && !key._canVerify) {
      throw ArgumentError.value(
          'private key', 'key', 'verify with the public key');
    }
  }

  final Set<String> algorithms;
  final String? issuer;
  final Set<String> audience;

  /// Clock skew allowed on `exp`, `nbf` and `iat`.
  final Duration leeway;

  /// Reject tokens without `exp`.
  final bool requireExpiry;

  /// When set, tokens need an `iat` no older than this.
  final Duration? maxAge;

  /// When set, the header's `typ` must equal it (`at+jwt` for OAuth access
  /// tokens, RFC 9068), so an ID token can't pass as an access token.
  final String? requiredType;

  /// Authorization scheme, compared case-insensitively.
  final String scheme;

  final JwtKeySet? _keys;
  final String? Function(Request request)? _tokenFromRequest;
  final JwtPrincipalMapper _toPrincipal;
  final DateTime Function() _now;

  /// The mapping used without `toPrincipal`. `null` when there is no `sub`.
  static Principal? defaultPrincipal(JwtClaims claims, Request request) {
    final sub = claims.subject;
    if (sub == null || sub.isEmpty) return null;
    return Principal(
      id: sub,
      roles: claims.strings('roles'),
      permissions: {
        ...claims.strings('scope'),
        ...claims.strings('permissions'),
      },
      claims: claims.toMap(),
    );
  }

  @override
  Future<Principal?> authenticate(Request request) async {
    final token = (_tokenFromRequest ?? _bearer)(request);
    if (token == null || token.isEmpty) return null;
    final claims = await verify(token);
    final principal = await _toPrincipal(claims, request);
    if (principal == null) throw _invalid();
    return principal;
  }

  /// Checks [token] and returns its claims, or throws an [HttpException]
  /// (401 `invalid_token` / `token_expired`).
  Future<JwtClaims> verify(String token) async {
    final parts = token.split('.');
    if (parts.length != 3) throw _invalid();

    final Map<String, Object?> header;
    try {
      header = (jsonDecode(utf8.decode(
              base64Url.decode(base64Url.normalize(parts[0])))) as Map)
          .cast<String, Object?>();
    } catch (_) {
      throw _invalid();
    }

    final alg = header['alg'];
    if (alg is! String || !algorithms.contains(alg)) throw _invalid();
    if (requiredType != null &&
        header['typ']?.toString().toLowerCase() !=
            requiredType!.toLowerCase()) {
      throw _invalid();
    }
    final kid = header['kid'];
    if (kid != null && kid is! String) throw _invalid();

    final key = await _keys!.find(kid as String?);
    if (key == null || !key._canVerify || !key._fits(alg)) throw _invalid();

    final Object? payload;
    try {
      // Only the signature: the claim checks below allow leeway and
      // require `exp`, which the library's own don't.
      payload = jose.JWT
          .verify(token, key._key,
              checkHeaderType: false,
              checkExpiresIn: false,
              checkNotBefore: false)
          .payload;
    } catch (_) {
      throw _invalid();
    }
    if (payload is! Map) throw _invalid();
    final claims =
        JwtClaims(payload.cast<String, Object?>(), header: header);
    _checkClaims(claims);
    return claims;
  }

  void _checkClaims(JwtClaims claims) {
    final now = _now().toUtc();
    for (final name in const ['exp', 'nbf', 'iat']) {
      if (claims.containsKey(name) && claims[name] is! num) throw _invalid();
    }

    final exp = claims.expiresAt;
    if (exp == null && requireExpiry) throw _invalid();
    if (exp != null && now.isAfter(exp.add(leeway))) throw _expired();

    final nbf = claims.notBefore;
    if (nbf != null && now.isBefore(nbf.subtract(leeway))) throw _invalid();

    final iat = claims.issuedAt;
    if (iat != null && now.isBefore(iat.subtract(leeway))) throw _invalid();
    if (maxAge != null) {
      if (iat == null) throw _invalid();
      if (now.isAfter(iat.add(maxAge!).add(leeway))) throw _expired();
    }

    if (issuer != null && claims.issuer != issuer) throw _invalid();
    if (audience.isNotEmpty && !claims.audience.any(audience.contains)) {
      throw _invalid();
    }
  }

  String? _bearer(Request request) {
    final header = request.headers['authorization'];
    if (header == null) return null;
    final space = header.indexOf(' ');
    if (space < 0) return null;
    if (header.substring(0, space).toLowerCase() != scheme.toLowerCase()) {
      return null;
    }
    return header.substring(space + 1).trim();
  }

  static HttpException _invalid() =>
      HttpException(401, 'Invalid token', code: 'invalid_token');

  static HttpException _expired() =>
      HttpException(401, 'Token expired', code: 'token_expired');
}

/// Issues tokens that a [JwtAuthenticator] with the same key, issuer and
/// audience accepts.
///
/// ```dart
/// final signer = JwtSigner(
///   key: JwtKey.hmac(env['JWT_SECRET']!),
///   algorithm: 'HS256',
///   issuer: 'my-app',
///   expiresIn: const Duration(days: 30),
/// );
/// final token = signer.sign(subject: '${user.id}', claims: {'roles': ['staff']});
/// ```
class JwtSigner {
  JwtSigner({
    required this.key,
    required this.algorithm,
    this.issuer,
    this.audience,
    this.expiresIn = const Duration(hours: 1),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    if (!supportedJwtAlgorithms.contains(algorithm) || !key._fits(algorithm)) {
      throw ArgumentError.value(algorithm, 'algorithm', 'does not fit the key');
    }
    if (!key._canSign) {
      throw ArgumentError.value(
          'public key', 'key', 'sign with the private key');
    }
  }

  final JwtKey key;
  final String algorithm;
  final String? issuer;

  /// `aud` written into every token.
  final String? audience;

  /// Default lifetime; [sign] can override it per token.
  final Duration expiresIn;

  final DateTime Function() _now;

  /// Signs a token with `iat`, `exp` and, when set, `sub`, `iss`, `aud` and
  /// `jti`. Entries in [claims] can't overwrite those.
  String sign({
    String? subject,
    Map<String, Object?> claims = const <String, Object?>{},
    Duration? expiresIn,
    String? jwtId,
  }) {
    final now = _now().toUtc();
    final ttl = expiresIn ?? this.expiresIn;
    final payload = <String, dynamic>{
      ...claims,
      'iat': now.millisecondsSinceEpoch ~/ 1000,
      'exp': now.add(ttl).millisecondsSinceEpoch ~/ 1000,
      if (subject != null) 'sub': subject,
      if (issuer != null) 'iss': issuer,
      if (audience != null) 'aud': audience,
      if (jwtId != null) 'jti': jwtId,
    };
    return jose.JWT(payload, header: {
      if (key.id != null) 'kid': key.id,
    }).sign(key._key,
        algorithm: jose.JWTAlgorithm.fromName(algorithm), noIssueAt: true);
  }
}
