/// Browser security headers (HSTS, nosniff, framing, referrer, CSP).
library gisila.runtime.middleware.security_headers;

import 'package:shelf/shelf.dart';

/// `Strict-Transport-Security` settings for [SecurityHeadersConfig.hsts].
class HstsConfig {
  const HstsConfig({
    this.maxAge = const Duration(days: 180),
    this.includeSubDomains = false,
    this.preload = false,
  });

  final Duration maxAge;

  /// Also pins every subdomain to https. Only turn on when all of them
  /// serve https.
  final bool includeSubDomains;

  /// Asks to be added to browsers' preload lists, which needs
  /// [includeSubDomains] and a [maxAge] of at least a year.
  final bool preload;

  String get value => [
        'max-age=${maxAge.inSeconds}',
        if (includeSubDomains) 'includeSubDomains',
        if (preload) 'preload',
      ].join('; ');
}

/// Headers [securityHeadersMiddleware] adds. Set a field to `null` to leave
/// that header out.
///
/// A header the handler already set is kept, so a route can loosen or
/// tighten its own (a page that must be framed, a stricter CSP).
class SecurityHeadersConfig {
  const SecurityHeadersConfig({
    this.hsts = const HstsConfig(),
    this.contentTypeOptions = 'nosniff',
    this.frameOptions = 'DENY',
    this.referrerPolicy = 'no-referrer',
    this.contentSecurityPolicy = "default-src 'none'; frame-ancestors 'none'",
    this.htmlContentSecurityPolicy,
    this.extra = const <String, String>{},
  });

  /// `Strict-Transport-Security`. Browsers ignore it on plain http, so it
  /// is safe to send from behind a TLS-terminating proxy.
  final HstsConfig? hsts;

  /// `X-Content-Type-Options`.
  final String? contentTypeOptions;

  /// `X-Frame-Options`.
  final String? frameOptions;

  /// `Referrer-Policy`.
  final String? referrerPolicy;

  /// `Content-Security-Policy` for responses that aren't HTML (JSON and
  /// the like). The default lets a browser load nothing from them and
  /// frame none of them.
  final String? contentSecurityPolicy;

  /// `Content-Security-Policy` for `text/html` responses. Off by default:
  /// pages such as API docs or an admin UI need a policy written for
  /// them, and a wrong one breaks them.
  final String? htmlContentSecurityPolicy;

  /// Any other headers to add (`Permissions-Policy`,
  /// `Cross-Origin-Opener-Policy`, ...).
  final Map<String, String> extra;
}

/// Adds the headers in [config] to every response that doesn't already
/// carry them.
Middleware securityHeadersMiddleware(SecurityHeadersConfig config) {
  final common = <String, String>{
    if (config.hsts != null) 'strict-transport-security': config.hsts!.value,
    if (config.contentTypeOptions != null)
      'x-content-type-options': config.contentTypeOptions!,
    if (config.frameOptions != null) 'x-frame-options': config.frameOptions!,
    if (config.referrerPolicy != null)
      'referrer-policy': config.referrerPolicy!,
    for (final e in config.extra.entries) e.key.toLowerCase(): e.value,
  };
  return (Handler inner) {
    return (Request request) async {
      final response = await inner(request);
      final isHtml = (response.headers['content-type'] ?? '')
          .toLowerCase()
          .startsWith('text/html');
      final csp = isHtml
          ? config.htmlContentSecurityPolicy
          : config.contentSecurityPolicy;
      // Only the missing keys: `change` merges them into the existing
      // headers, keeping multi-value ones such as Set-Cookie intact.
      final add = <String, String>{
        for (final e in common.entries)
          if (!response.headers.containsKey(e.key)) e.key: e.value,
        if (csp != null &&
            !response.headers.containsKey('content-security-policy'))
          'content-security-policy': csp,
      };
      return add.isEmpty ? response : response.change(headers: add);
    };
  };
}
