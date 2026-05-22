/// `application/x-www-form-urlencoded` and `multipart/form-data` body
/// parsers.
///
/// Ported from the same pattern used in `bita_backends`. The
/// parser produces a uniform [FormData] container that:
///
/// * exposes string fields via [FormData.fields],
/// * exposes uploaded files via [FormData.files],
/// * and *also* behaves as a `Map<String, dynamic>` (via
///   [MapMixin]) so it slots straight into a controller method that
///   accepts `Map<String, dynamic> body` or a custom
///   `fromForm(Map<String, dynamic>)` factory.
///
/// The parser throws [BadRequestException] on a missing / unsupported
/// content type so the framework's global error mapper renders the
/// failure as a uniform `400` envelope.
library gisila.runtime.parsers.form_data;

import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

import '../codec.dart' show BadRequestException;

/// `Content-Type: application/x-www-form-urlencoded`
final formUrlEncodedContentType = ContentType(
  'application',
  'x-www-form-urlencoded',
);

/// `Content-Type: multipart/form-data`
final multipartFormDataContentType = ContentType(
  'multipart',
  'form-data',
);

/// Parses the body as form data and returns a [FormData] container.
///
/// Throws [BadRequestException] if the MIME type is neither
/// `application/x-www-form-urlencoded` nor `multipart/form-data`.
///
/// Accepts the building blocks directly (`headers`, `body`, `bytes`)
/// rather than a `Request` so it can be unit-tested without a Shelf
/// pipeline, and so [readFormBody] can wrap a Shelf request without
/// repeating the dispatch logic.
Future<FormData> parseFormData({
  required Map<String, String> headers,
  required Future<String> Function() body,
  required Stream<List<int>> Function() bytes,
}) async {
  final contentType = _extractContentType(headers);
  final isFormUrlEncoded = _isFormUrlEncoded(contentType);
  final isMultipartFormData = _isMultipartFormData(contentType);

  if (!isFormUrlEncoded && !isMultipartFormData) {
    throw BadRequestException(
      'Body could not be parsed as form data due to an invalid MIME type. '
      'Expected "${formUrlEncodedContentType.mimeType}" or '
      '"${multipartFormDataContentType.mimeType}", '
      'got "${contentType?.mimeType ?? ''}"',
    );
  }

  return isFormUrlEncoded
      ? _extractFormUrlEncodedFormData(body: await body())
      : await _extractMultipartFormData(headers: headers, bytes: bytes());
}

ContentType? _extractContentType(Map<String, String> headers) {
  final contentTypeValue = headers[HttpHeaders.contentTypeHeader];
  if (contentTypeValue == null) return null;
  try {
    return ContentType.parse(contentTypeValue);
  } on FormatException {
    return null;
  }
}

bool _isFormUrlEncoded(ContentType? contentType) {
  if (contentType == null) return false;
  return contentType.mimeType == formUrlEncodedContentType.mimeType;
}

bool _isMultipartFormData(ContentType? contentType) {
  if (contentType == null) return false;
  return contentType.mimeType == multipartFormDataContentType.mimeType;
}

FormData _extractFormUrlEncodedFormData({required String body}) {
  return FormData(
    fields: Uri.splitQueryString(body),
    files: <String, UploadedFile>{},
  );
}

/// Matches `name="value"` pairs inside a `Content-Disposition` header.
final _keyValueRegexp =
    RegExp('(?:(?<key>[a-zA-Z0-9-_]+)="(?<value>.*?)";*)+');

Future<FormData> _extractMultipartFormData({
  required Map<String, String> headers,
  required Stream<List<int>> bytes,
}) async {
  final contentType = headers[HttpHeaders.contentTypeHeader]!;
  final mediaType = MediaType.parse(contentType);
  final boundary = mediaType.parameters['boundary'];
  if (boundary == null || boundary.isEmpty) {
    throw BadRequestException(
        'multipart/form-data is missing the "boundary" parameter.');
  }
  final transformer = MimeMultipartTransformer(boundary);

  final fields = <String, String>{};
  final files = <String, UploadedFile>{};

  await for (final part in transformer.bind(bytes)) {
    final contentDisposition = part.headers['content-disposition'];
    if (contentDisposition == null) continue;
    if (!contentDisposition.startsWith('form-data;')) continue;

    final values = _keyValueRegexp
        .allMatches(contentDisposition)
        .fold(<String, String>{}, (map, match) {
      map[match.namedGroup('key')!] = match.namedGroup('value')!;
      return map;
    });

    final name = values['name'];
    if (name == null) continue;
    final fileName = values['filename'];

    if (fileName != null) {
      ContentType partContentType;
      try {
        partContentType =
            ContentType.parse(part.headers['content-type'] ?? 'text/plain');
      } on FormatException {
        partContentType = ContentType('text', 'plain');
      }
      files[name] = UploadedFile(fileName, partContentType, part);
    } else {
      final partBytes =
          (await part.toList()).fold(<int>[], (p, e) => p..addAll(e));
      fields[name] = utf8.decode(partBytes);
    }
  }

  return FormData(fields: fields, files: files);
}

/// The fields and files of a received form data request.
///
/// `FormData` *is* a `Map<String, dynamic>` (via [MapMixin]) so a
/// controller method declared as `Map<String, dynamic> body` works
/// out of the box for form-urlencoded / multipart requests. Files
/// appear in the map as [UploadedFile] values; text fields appear as
/// `String` values.
class FormData with MapMixin<String, Object> {
  FormData({
    required Map<String, String> fields,
    required Map<String, UploadedFile> files,
  })  : _fields = fields,
        _files = files;

  final Map<String, String> _fields;
  final Map<String, UploadedFile> _files;

  /// The text fields that were submitted in the form.
  Map<String, String> get fields => Map.unmodifiable(_fields);

  /// The files that were uploaded in the form.
  Map<String, UploadedFile> get files => Map.unmodifiable(_files);

  // ---- MapMixin implementation ----

  @override
  Object? operator [](Object? key) => _fields[key] ?? _files[key];

  @override
  Iterable<String> get keys => <String>{..._fields.keys, ..._files.keys};

  @override
  void operator []=(String key, Object value) {
    throw UnsupportedError('FormData is immutable');
  }

  @override
  void clear() => throw UnsupportedError('FormData is immutable');

  @override
  Object? remove(Object? key) =>
      throw UnsupportedError('FormData is immutable');

  @override
  String toString() =>
      'FormData(fields: ${_fields.keys.toList()}, '
      'files: ${_files.keys.toList()})';
}

/// A single uploaded file extracted from a `multipart/form-data`
/// request.
///
/// The bytes are exposed as a single-shot `Stream<List<int>>`; call
/// [readAsBytes] to drain it into a `List<int>` or [openRead] to
/// stream directly to disk / S3 / etc. Each accessor consumes the
/// stream once.
class UploadedFile {
  UploadedFile(this.name, this.contentType, this._byteStream);

  /// The original filename as reported by the client.
  final String name;

  /// The MIME type reported in the part's `Content-Type` header
  /// (defaults to `text/plain` when omitted).
  final ContentType contentType;

  final Stream<List<int>> _byteStream;

  /// Reads the entire file into memory.
  ///
  /// Can only be called once - the underlying stream is consumed.
  Future<List<int>> readAsBytes() async {
    final chunks = await _byteStream.toList();
    return chunks.fold<List<int>>(<int>[], (p, e) => p..addAll(e));
  }

  /// Returns the raw byte stream so callers can pipe it directly.
  ///
  /// Can only be called once.
  Stream<List<int>> openRead() => _byteStream;

  @override
  String toString() => 'UploadedFile(name: $name, contentType: $contentType)';
}
