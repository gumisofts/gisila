/// Serving files from a directory, with an optional single-page-app
/// fallback.
library gisila.runtime.static_files;

import 'dart:io';

import 'package:http_parser/http_parser.dart' show formatHttpDate, parseHttpDate;
import 'package:mime/mime.dart' show lookupMimeType;
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart' show Router;

import 'middleware/etag.dart' show ifNoneMatchHits;

/// Settings for [staticFilesHandler] / `GisilaApp.serveStatic`.
class StaticFilesConfig {
  const StaticFilesConfig({
    this.indexFile = 'index.html',
    this.spaFallback = false,
    this.maxAge = Duration.zero,
    this.immutable,
    this.allowDotfiles = false,
  });

  /// Served for a directory (`/` or `/docs/`). `null` serves none.
  final String? indexFile;

  /// Answer unknown paths that look like page routes (`GET`, no file
  /// extension, `Accept: text/html`) with the root [indexFile], so a
  /// client-side router can handle them. API calls and missing assets
  /// still get a 404.
  final bool spaFallback;

  /// `Cache-Control: max-age` for files. HTML files always get `no-cache`
  /// so a new deploy is picked up; they're still revalidated cheaply
  /// through `ETag` / `Last-Modified`.
  final Duration maxAge;

  /// Files whose path (relative to the directory) matches get
  /// `max-age=31536000, immutable`: use it for names that carry a content
  /// hash, like `RegExp(r'^assets/.*\.[0-9a-f]{8,}\.')`.
  final RegExp? immutable;

  /// Serve files and directories whose name starts with a dot (`.env`,
  /// `.git`). Off by default.
  final bool allowDotfiles;
}

/// A handler serving files under [directory]. Mount it on a router (or use
/// `GisilaApp.serveStatic`); paths it doesn't have answer
/// [Router.routeNotFound], so the router moves on to its next route or its
/// 404.
///
/// Never serves anything outside [directory]: `..` segments are refused
/// and symlinks pointing out of it are treated as missing. No directory
/// listings, no dotfiles (unless [StaticFilesConfig.allowDotfiles]).
Handler staticFilesHandler(String directory,
    [StaticFilesConfig config = const StaticFilesConfig()]) {
  final rootDir = Directory(directory);
  if (!rootDir.existsSync()) {
    throw ArgumentError.value(directory, 'directory', 'does not exist');
  }
  final root = rootDir.resolveSymbolicLinksSync();

  Future<File?> resolve(List<String> segments) async {
    if (segments.any((s) =>
        s == '..' ||
        s == '.' ||
        s.contains('/') ||
        s.contains('\\') ||
        s.contains('\u0000') ||
        (!config.allowDotfiles && s.startsWith('.')))) {
      return null;
    }
    var path = p.joinAll([root, ...segments]);
    final type = await FileSystemEntity.type(path);
    if (type == FileSystemEntityType.notFound) return null;
    final real = await File(path).resolveSymbolicLinks();
    if (real != root && !p.isWithin(root, real)) return null;
    if (await FileSystemEntity.isDirectory(real)) {
      if (config.indexFile == null) return null;
      path = p.join(real, config.indexFile);
      if (!await File(path).exists()) return null;
      final realIndex = await File(path).resolveSymbolicLinks();
      if (!p.isWithin(root, realIndex)) return null;
      return File(realIndex);
    }
    return File(real);
  }

  return (Request request) async {
    if (request.method != 'GET' && request.method != 'HEAD') {
      return Router.routeNotFound;
    }
    final segments =
        request.url.pathSegments.where((s) => s.isNotEmpty).toList();
    var file = await resolve(segments);
    if (file == null && config.spaFallback && _looksLikePage(request)) {
      file = await resolve(const []);
    }
    if (file == null) return Router.routeNotFound;
    return _serve(request, file, root, config);
  };
}

bool _looksLikePage(Request request) {
  final segments = request.url.pathSegments;
  final last = segments.isEmpty ? '' : segments.last;
  return !last.contains('.') &&
      (request.headers['accept'] ?? '').contains('text/html');
}

Future<Response> _serve(
    Request request, File file, String root, StaticFilesConfig config) async {
  final stat = await file.stat();
  final modified = stat.modified.toUtc();
  final etag = 'W/"${stat.size.toRadixString(16)}-'
      '${modified.millisecondsSinceEpoch.toRadixString(16)}"';
  final relative = p.relative(file.path, from: root).replaceAll(r'\', '/');
  final contentType =
      lookupMimeType(file.path) ?? 'application/octet-stream';
  final isHtml = contentType == 'text/html';

  final String cacheControl;
  if (isHtml) {
    cacheControl = 'no-cache';
  } else if (config.immutable?.hasMatch(relative) ?? false) {
    cacheControl = 'public, max-age=31536000, immutable';
  } else if (config.maxAge > Duration.zero) {
    cacheControl = 'public, max-age=${config.maxAge.inSeconds}';
  } else {
    cacheControl = 'no-cache';
  }

  final headers = <String, String>{
    'etag': etag,
    'last-modified': formatHttpDate(modified),
    'cache-control': cacheControl,
  };

  final ifNoneMatch = request.headers['if-none-match'];
  if (ifNoneMatch != null) {
    if (ifNoneMatchHits(ifNoneMatch, etag)) {
      return Response.notModified(headers: headers);
    }
  } else {
    final since = request.headers['if-modified-since'];
    if (since != null) {
      try {
        // HTTP dates have whole seconds.
        if (!modified.isAfter(parseHttpDate(since)
            .add(const Duration(milliseconds: 999)))) {
          return Response.notModified(headers: headers);
        }
      } on FormatException {
        // Ignore a malformed date and send the file.
      }
    }
  }

  return Response.ok(
    // dart:io drops the body of a HEAD response.
    file.openRead(),
    headers: {
      ...headers,
      'content-type':
          isHtml || contentType.startsWith('text/')
              ? '$contentType; charset=utf-8'
              : contentType,
      'content-length': '${stat.size}',
    },
  );
}
