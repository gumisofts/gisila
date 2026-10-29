/// Authentication abstraction.
library gisila.runtime.auth.authenticator;

import 'package:shelf/shelf.dart';

import 'principal.dart';

/// Resolves an HTTP request to a [Principal] (or `null` if anonymous).
///
/// Implementations should *never* throw on a "merely unauthenticated"
/// request - return `null` and let the framework emit the appropriate
/// `401`. Throwing is reserved for genuinely malformed credentials
/// (e.g. a corrupt JWT signature) and will surface as a `401` with the
/// exception message.
abstract class Authenticator {
  const Authenticator();

  Future<Principal?> authenticate(Request request);
}

/// An [Authenticator] that always returns `null`. Used as the default
/// when none is configured - any [`RequireAuth`]-guarded route will
/// then reject with `401`.
class NullAuthenticator extends Authenticator {
  const NullAuthenticator();

  @override
  Future<Principal?> authenticate(Request request) async => null;
}

/// Simple in-memory authenticator: maps `Authorization: Bearer <token>`
/// to a pre-registered [Principal]. Convenient for tests and demos.
class StaticTokenAuthenticator extends Authenticator {
  const StaticTokenAuthenticator(this._tokens, {this.scheme = 'Bearer'});

  final Map<String, Principal> _tokens;
  final String scheme;

  @override
  Future<Principal?> authenticate(Request request) async {
    final header = request.headers['authorization'];
    if (header == null) return null;
    final prefix = '$scheme ';
    if (!header.startsWith(prefix)) return null;
    final token = header.substring(prefix.length).trim();
    return _tokens[token];
  }
}

/// Tries [authenticators] in order and returns the first principal found,
/// so an API can take, say, JWTs from browsers and API keys from scripts:
///
/// ```dart
/// CompositeAuthenticator([
///   JwtAuthenticator(key: key, algorithms: {'HS256'}),
///   ApiKeyAuthenticator(lookup: findKey),
/// ])
/// ```
///
/// An authenticator that throws (credentials present but bad) ends the
/// search with that error: a rejected token is never retried as something
/// else.
class CompositeAuthenticator extends Authenticator {
  CompositeAuthenticator(Iterable<Authenticator> authenticators)
      : authenticators = List.unmodifiable(authenticators) {
    if (this.authenticators.isEmpty) {
      throw ArgumentError.value(authenticators, 'authenticators', 'is empty');
    }
  }

  final List<Authenticator> authenticators;

  @override
  Future<Principal?> authenticate(Request request) async {
    for (final a in authenticators) {
      final principal = await a.authenticate(request);
      if (principal != null) return principal;
    }
    return null;
  }
}
