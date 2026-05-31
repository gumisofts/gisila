/// Typed declarative form base class.
///
/// A [Form] subclass declares one [FormField] per request input it
/// wants to accept. The framework reads the request body, gives every
/// declared field exactly the slice it asked for, runs the field's
/// `parse` + `validators`, and exposes the cleaned typed value via
/// [FormField.value].
///
/// Key guarantees:
///
/// * Only fields listed in [collectFields] are read. Undeclared keys
///   in the request body are silently ignored.
/// * [FormField.value] is the **parsed** value (after `parse`), never
///   the raw `String` / `Object?` from the body.
/// * Unsupported content types throw [BadRequestException]; the loose
///   `return {}` of the old `form()` helper is gone.
/// * The same [Form] subclass binds JSON, urlencoded, and multipart
///   bodies; pick the field types accordingly (e.g. [FileField] only
///   makes sense for multipart).
/// * Validation failures throw [FormValidationException] which the
///   framework error middleware maps to a `400` envelope containing
///   `{fieldName: errorMessage}`.
library gisila.runtime.forms.form;

import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

import '../codec.dart' show BadRequestException;
import '../parsers/form_data.dart';
import 'fields.dart';

/// Thrown by [Form.bind] / [bindForm] when one or more declared fields
/// fail to parse or validate.
///
/// [errors] is a `Map<fieldName, message>` so handlers (or the
/// framework's global error middleware) can render it directly as a
/// structured `400` body.
class FormValidationException implements Exception {
  FormValidationException({
    required this.errors,
    this.message = 'Invalid form data',
  });

  final String message;
  final Map<String, String> errors;

  @override
  String toString() => 'FormValidationException($message): $errors';
}

/// Base class for a typed request form.
///
/// ```dart
/// class RegisterForm extends Form {
///   final email     = EmailField(required: true);
///   final password  = PasswordField(required: true);
///   final firstName = StringField(name: 'firstName');
///   final lastName  = StringField(name: 'lastName');
///
///   @override
///   List<FormField<Object?>> collectFields() =>
///       [email, password, firstName, lastName];
/// }
/// ```
abstract class Form {
  Form();

  /// Lazy snapshot of the declared field list. Computed exactly once
  /// per instance, on first access.
  late final List<FormField<Object?>> _fields = collectFields();

  /// Declared by every subclass. Order is preserved in error envelopes
  /// only as a courtesy; consumers shouldn't depend on it.
  List<FormField<Object?>> collectFields();

  /// All declared fields, in declaration order.
  List<FormField<Object?>> get fields => List.unmodifiable(_fields);

  /// Reads exactly the declared fields out of [data] and populates each
  /// [FormField] with its parsed value.
  ///
  /// Accumulates per-field errors and throws a single
  /// [FormValidationException] at the end so the client sees every
  /// problem in one round trip.
  Future<void> bind(Map<String, Object?> data) async {
    final errors = <String, String>{};
    for (final field in _fields) {
      try {
        await field.bind(data[field.name]);
      } on FormValidationException catch (e) {
        if (e.errors.isNotEmpty) {
          errors.addAll(e.errors);
        } else {
          errors[field.name] = e.message;
        }
      } catch (e) {
        errors[field.name] = e.toString();
      }
    }
    if (errors.isNotEmpty) {
      throw FormValidationException(errors: errors);
    }
  }

  /// Returns the cleaned, declared-only values as a plain map. Useful
  /// when forwarding to repositories that take a payload map.
  Map<String, Object?> toMap() => <String, Object?>{
        for (final f in _fields)
          if (f.isSet) f.name: f.rawValue,
      };
}

/// Reads [request], decodes its body, and binds it to a fresh
/// instance of [F] (constructed via [ctor]).
///
/// Content-type dispatch:
///
/// * `application/json` (and `text/json`, `application/vnd.api+json`)
///   → `jsonDecode` then bind.
/// * `application/x-www-form-urlencoded` and `multipart/form-data` →
///   [parseFormData] then bind. [FileField]s pull from the multipart
///   `files` map; every other field pulls from `fields`.
/// * Empty body / missing `Content-Type` → bind against an empty map
///   so `required` fields surface as validation errors (consistent
///   with form-encoded clients that drop empty values).
/// * Anything else → [BadRequestException]. No silent return.
Future<F> bindForm<F extends Form>(
  Request request,
  F Function() ctor,
) async {
  final form = ctor();
  final raw = request.headers[HttpHeaders.contentTypeHeader];
  final mime = raw?.split(';').first.trim().toLowerCase();

  Map<String, Object?> data;
  switch (mime) {
    case null:
    case '':
      data = const <String, Object?>{};
      break;

    case 'application/json':
    case 'application/vnd.api+json':
    case 'text/json':
      final body = await request.readAsString();
      if (body.isEmpty) {
        data = const <String, Object?>{};
      } else {
        try {
          final decoded = jsonDecode(body);
          if (decoded is! Map) {
            throw BadRequestException(
              'JSON body must be an object for form binding.',
            );
          }
          data = decoded.cast<String, Object?>();
        } on FormatException catch (e) {
          throw BadRequestException('Malformed JSON body: ${e.message}');
        }
      }
      break;

    case 'application/x-www-form-urlencoded':
    case 'multipart/form-data':
      final formdata = await parseFormData(
        headers: request.headers,
        body: request.readAsString,
        bytes: request.read,
      );
      data = <String, Object?>{
        ...formdata.fields,
        ...formdata.files,
      };
      break;

    default:
      throw BadRequestException(
        'Unsupported Content-Type "$mime" for form binding. Expected one of: '
        'application/json, application/x-www-form-urlencoded, '
        'multipart/form-data.',
      );
  }

  await form.bind(data);
  return form;
}
