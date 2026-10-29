/// API-key authentication: keys are stored hashed and looked up by hash.
library gisila.runtime.auth.api_key;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' show sha256;
import 'package:shelf/shelf.dart';

import '../exceptions.dart';
import 'authenticator.dart';
import 'principal.dart';

/// Finds the principal for an API key by its [hash] (see
/// [ApiKeyAuthenticator.hash]). Return `null` for unknown or revoked keys.
typedef ApiKeyLookup = FutureOr<Principal?> Function(
    String hash, Request request);

/// Authenticates requests carrying an API key, by default in the
/// `X-API-Key` header.
///
/// Store only [hash]es of the keys you issue, never the keys:
///
/// ```dart
/// // Issuing:
/// final key = ApiKeyAuthenticator.generate(prefix: 'sk_live_');
/// await db.apiKeys.insert(hash: ApiKeyAuthenticator.hash(key), owner: ...);
/// // ...show `key` to the user once.
///
/// // Checking:
/// authenticator: ApiKeyAuthenticator(
///   lookup: (hash, request) async {
///     final row = await db.apiKeys.findActive(hash);
///     return row == null
///         ? null
///         : Principal(id: row.owner, permissions: row.scopes);
///   },
/// ),
/// ```
///
/// No key is anonymous (`null`); a key that [lookup] doesn't know is a 401
/// with code `invalid_api_key`.
class ApiKeyAuthenticator extends Authenticator {
  ApiKeyAuthenticator({
    required ApiKeyLookup lookup,
    String header = 'X-API-Key',
    String? Function(Request request)? keyFromRequest,
  })  : _lookup = lookup,
        _header = header.toLowerCase(),
        _keyFromRequest = keyFromRequest;

  final ApiKeyLookup _lookup;
  final String _header;
  final String? Function(Request request)? _keyFromRequest;

  /// Longest key accepted; anything longer is rejected unhashed.
  static const int maxKeyLength = 256;

  /// The value to store for [key]: its SHA-256, hex-encoded. Keys made by
  /// [generate] carry 256 random bits, so a fast hash is enough.
  static String hash(String key) =>
      sha256.convert(utf8.encode(key)).toString();

  /// A new random key: [prefix] followed by 32 random bytes, base64url.
  /// A prefix (`sk_live_`) makes keys recognisable to secret scanners and
  /// to people.
  static String generate({String prefix = ''}) {
    final rnd = Random.secure();
    final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
    return '$prefix${base64Url.encode(bytes).replaceAll('=', '')}';
  }

  @override
  Future<Principal?> authenticate(Request request) async {
    final key = (_keyFromRequest ?? _fromHeader)(request)?.trim();
    if (key == null || key.isEmpty) return null;
    if (key.length > maxKeyLength) throw _invalid();
    final principal = await _lookup(hash(key), request);
    if (principal == null) throw _invalid();
    return principal;
  }

  String? _fromHeader(Request request) => request.headers[_header];

  static HttpException _invalid() =>
      HttpException(401, 'Invalid API key', code: 'invalid_api_key');
}
