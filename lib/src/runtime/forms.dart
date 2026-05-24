/// Form field validation helpers.
///
/// Provides [FieldValidator] (and the typed subclass [EmailVerifier]) for
/// declaring which fields a request body must contain, along with the [form]
/// helper that reads a Shelf [Request], validates it against a list of
/// [FieldValidator]s, and returns the validated data as a
/// `Map<String, dynamic>`.
///
/// Supported content types:
/// * `application/json`
/// * `application/x-www-form-urlencoded`
/// * `multipart/form-data`
///
/// On validation failure [form] throws [FieldValidationException] which
/// carries a per-field error map so callers can return a structured 400
/// response.
library gisila.runtime.forms;

import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

import 'parsers/form_data.dart';

/// Thrown by [form] when one or more field validations fail.
///
/// [error] is a `Map<fieldName, errorMessage>` so callers can return it
/// directly as a structured JSON 400 body.
class FieldValidationException implements Exception {
  FieldValidationException({
    required this.error,
    this.msg = 'Invalid field',
  });

  final String msg;
  final Map<String, dynamic> error;

  @override
  String toString() => 'FieldValidationException($msg): $error';
}

/// A validated field with its [name] and parsed [content].
class Field<T> {
  Field({required this.name, required this.content});

  final String name;
  final T content;
}

/// Declares a single form / JSON body field that [form] should extract and
/// validate.
///
/// * [name] must match the key in the request body.
/// * [isRequired] causes [form] to add an error if the key is absent.
/// * [validator] receives the (optionally [parse]d) value and returns a
///   non-null error string on failure.
/// * [parse] converts the raw `String` value (e.g. from form-urlencoded) to
///   the expected type [T] before validation.
class FieldValidator<T> {
  FieldValidator({
    required this.name,
    this.isRequired = false,
    this.validator,
    this.parse,
  });

  final String name;
  final bool isRequired;
  final String? Function(T value)? validator;
  final T Function(String value)? parse;

  String? validate(T value) {
    if (validator == null) return null;
    return validator!(value);
  }
}

/// A [FieldValidator] specialised for e-mail string fields.
///
/// Extend or use directly; the default [validator] is `null` so the
/// caller can provide a custom one or rely on [emailFieldValidator].
class EmailVerifier extends FieldValidator<String> {
  EmailVerifier({
    required super.name,
    super.isRequired = false,
    super.validator,
  });
}

/// Ready-made validator that checks `name@domain.tld` format.
final emailFieldValidator = FieldValidator<String>(
  name: 'email',
  validator: (value) {
    if (!RegExp(r'.+@.+\..{3}').hasMatch(value)) {
      return r'Invalid email format. Expected .+@.+\..{3}';
    }
    return null;
  },
);

/// Ready-made validator that rejects spaces and values longer than 255 chars.
final nameFieldValidator = FieldValidator<String>(
  name: 'name',
  validator: (value) {
    if (value.contains(' ')) return 'This field must not contain spaces';
    if (value.length > 255) return 'This field exceeds the 255-character limit';
    return null;
  },
);

/// Reads the [request] body, validates every declared [fields] entry, and
/// returns the valid data as a `Map<String, dynamic>`.
///
/// Content-type dispatch:
/// * `application/json` — body decoded with `jsonDecode`
/// * `multipart/form-data` / `application/x-www-form-urlencoded` — parsed
///   with [parseFormData]; both string fields and [UploadedFile] values are
///   accessible by name.
///
/// Throws [FieldValidationException] if any field fails validation so the
/// caller (or the framework's global error handler) can return a 400.
Future<Map<String, dynamic>> form(
  Request request, {
  required List<FieldValidator<dynamic>> fields,
}) async {
  final contentType =
      request.headers[HttpHeaders.contentTypeHeader]?.split(';').first;

  if (contentType == ContentType.json.value) {
    final raw = await request.readAsString();
    final data = (jsonDecode(raw)) as Map<String, dynamic>;
    return _validateFields(data, fields);
  }

  if (contentType == 'multipart/form-data' ||
      contentType == 'application/x-www-form-urlencoded') {
    final formdata = await parseFormData(
      headers: request.headers,
      body: request.readAsString,
      bytes: request.read,
    );
    final data = <String, dynamic>{
      ...formdata.fields,
      ...formdata.files,
    };
    return _validateFields(data, fields);
  }

  return {};
}

Map<String, dynamic> _validateFields(
  Map<String, dynamic> data,
  List<FieldValidator<dynamic>> fields,
) {
  final err = <String, dynamic>{};
  final validatedData = <String, dynamic>{};

  for (final field in fields) {
    if (field.isRequired && data[field.name] == null) {
      err[field.name] = 'This field is required';
      continue;
    }

    if (data[field.name] == null) continue;

    try {
      final fieldData = field.parse != null
          ? field.parse!(data[field.name] as String)
          : data[field.name];
      final error = field.validate(fieldData);
      if (error != null) {
        err[field.name] = error;
      }
      validatedData[field.name] = data[field.name];
    } catch (e) {
      err[field.name] = e.toString();
    }
  }

  if (err.isNotEmpty) {
    throw FieldValidationException(error: err);
  }

  return validatedData;
}
