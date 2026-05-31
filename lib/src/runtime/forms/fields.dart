/// Typed [FormField] hierarchy.
///
/// A [FormField] knows three things:
///
/// 1. Its [name] (the key under which it appears in the request body).
/// 2. How to [parse] a raw value (string, number, multipart part…)
///    into its typed [T].
/// 3. A list of optional [validators] that run **after** parsing and
///    return a non-null error message on failure.
///
/// Concrete fields below cover the common cases (string, int, double,
/// bool, DateTime, email, password, file). For anything else, extend
/// [FormField] directly.
library gisila.runtime.forms.fields;

import '../parsers/form_data.dart';
import 'form.dart';

/// Validator signature. Returns `null` when [value] is valid, an error
/// message otherwise.
typedef FieldValidator<T> = String? Function(T value);

/// Abstract typed form field.
///
/// `T` is the **parsed** value type. Implementations override [parse]
/// to turn the raw body value into [T]. Validators that run on the
/// parsed value live in [validators].
abstract class FormField<T> {
  FormField({
    required this.name,
    this.required = false,
    this.validators = const <FieldValidator<Never>>[],
  });

  /// The key this field reads from the request body.
  final String name;

  /// When `true`, an absent / empty value triggers a "field is
  /// required" validation error.
  final bool required;

  /// Validators applied to the parsed value. Each returns `null` on
  /// success or an error message on failure.
  ///
  /// Declared as `List<FieldValidator<Never>>` so subclass field
  /// constructors can accept their concrete `FieldValidator<T>` lists
  /// (a covariant `List` is still a valid `List<FieldValidator<Never>>`
  /// in Dart). Each validator is invoked dynamically inside
  /// [_runValidators] which casts to the field's actual `T`.
  final List<FieldValidator<Never>> validators;

  T? _value;
  bool _isSet = false;

  /// The parsed value. `null` when the field was absent and not
  /// [required], or when binding has not yet happened.
  T? get value => _value;

  /// Same as [value] but exposed as `Object?` for the framework's
  /// generic `toMap()` view.
  Object? get rawValue => _value;

  /// `true` once [bind] has been called for this field (even if the
  /// value parsed to `null`).
  bool get isSet => _isSet;

  /// Whether [raw] should be treated as "absent". By default an
  /// uploaded [String] of empty value is treated as missing so HTML
  /// forms (which always send all keys) behave intuitively.
  bool isAbsent(Object? raw) {
    if (raw == null) return true;
    if (raw is String && raw.isEmpty) return true;
    return false;
  }

  /// Parses [raw] (the value pulled out of the request body) into [T].
  /// Implementations may throw any exception; [bind] turns it into a
  /// per-field validation error.
  T parse(Object? raw);

  /// Reads the field from the request body slot, runs [parse] and
  /// [validators], stores the result. Called by [Form.bind] - not
  /// usually called by hand.
  Future<void> bind(Object? raw) async {
    if (isAbsent(raw)) {
      if (required) {
        throw FormValidationException(errors: {name: 'This field is required'});
      }
      _value = null;
      _isSet = true;
      return;
    }

    final T parsed;
    try {
      parsed = parse(raw);
    } on FormValidationException {
      rethrow;
    } catch (e) {
      throw FormValidationException(errors: {name: e.toString()});
    }

    _runValidators(parsed);
    _value = parsed;
    _isSet = true;
  }

  void _runValidators(T value) {
    for (final v in validators) {
      final dynamic dyn = v;
      final String? err = dyn(value) as String?;
      if (err != null) {
        throw FormValidationException(errors: {name: err});
      }
    }
  }
}

// ---------------------------------------------------------------------------
// String-family fields
// ---------------------------------------------------------------------------

/// String field. Optionally enforces length bounds and a custom regexp.
class StringField extends FormField<String> {
  StringField({
    required super.name,
    super.required = false,
    super.validators = const <FieldValidator<String>>[],
    this.minLength,
    this.maxLength,
    this.pattern,
    this.trim = true,
  });

  final int? minLength;
  final int? maxLength;
  final RegExp? pattern;

  /// When `true` (default), incoming strings are `.trim()`-ed before
  /// length / pattern checks.
  final bool trim;

  @override
  String parse(Object? raw) {
    if (raw is! String) {
      throw FormValidationException(
        errors: {name: 'Expected a string value'},
      );
    }
    final v = trim ? raw.trim() : raw;
    if (minLength != null && v.length < minLength!) {
      throw FormValidationException(
        errors: {name: 'Must be at least $minLength characters'},
      );
    }
    if (maxLength != null && v.length > maxLength!) {
      throw FormValidationException(
        errors: {name: 'Must be at most $maxLength characters'},
      );
    }
    if (pattern != null && !pattern!.hasMatch(v)) {
      throw FormValidationException(
        errors: {name: 'Does not match the expected pattern'},
      );
    }
    return v;
  }
}

/// E-mail field. Default pattern matches `.+@.+\..{2,}`.
class EmailField extends StringField {
  EmailField({
    required super.name,
    super.required = false,
    super.validators = const <FieldValidator<String>>[],
    super.minLength,
    super.maxLength,
    super.trim = true,
  }) : super(pattern: _emailRegex);

  static final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
}

/// Password field. Enforces a configurable minimum length (default
/// `8`) but otherwise treats the value as an opaque string.
class PasswordField extends StringField {
  PasswordField({
    required super.name,
    super.required = false,
    super.validators = const <FieldValidator<String>>[],
    int minLength = 8,
    super.maxLength,
  }) : super(minLength: minLength, trim: false);
}

// ---------------------------------------------------------------------------
// Numeric / boolean fields
// ---------------------------------------------------------------------------

/// Integer field. Parses string and numeric inputs.
class IntField extends FormField<int> {
  IntField({
    required super.name,
    super.required = false,
    super.validators = const <FieldValidator<int>>[],
    this.min,
    this.max,
  });

  final int? min;
  final int? max;

  @override
  int parse(Object? raw) {
    int v;
    if (raw is int) {
      v = raw;
    } else if (raw is num) {
      v = raw.toInt();
    } else if (raw is String) {
      final parsed = int.tryParse(raw.trim());
      if (parsed == null) {
        throw FormValidationException(errors: {name: 'Must be an integer'});
      }
      v = parsed;
    } else {
      throw FormValidationException(errors: {name: 'Must be an integer'});
    }
    if (min != null && v < min!) {
      throw FormValidationException(errors: {name: 'Must be ≥ $min'});
    }
    if (max != null && v > max!) {
      throw FormValidationException(errors: {name: 'Must be ≤ $max'});
    }
    return v;
  }
}

/// Floating-point field. Accepts `int`, `double`, `num`, or numeric
/// string representations.
class DoubleField extends FormField<double> {
  DoubleField({
    required super.name,
    super.required = false,
    super.validators = const <FieldValidator<double>>[],
    this.min,
    this.max,
  });

  final double? min;
  final double? max;

  @override
  double parse(Object? raw) {
    double v;
    if (raw is double) {
      v = raw;
    } else if (raw is num) {
      v = raw.toDouble();
    } else if (raw is String) {
      final parsed = double.tryParse(raw.trim());
      if (parsed == null) {
        throw FormValidationException(errors: {name: 'Must be a number'});
      }
      v = parsed;
    } else {
      throw FormValidationException(errors: {name: 'Must be a number'});
    }
    if (min != null && v < min!) {
      throw FormValidationException(errors: {name: 'Must be ≥ $min'});
    }
    if (max != null && v > max!) {
      throw FormValidationException(errors: {name: 'Must be ≤ $max'});
    }
    return v;
  }
}

/// Boolean field. Accepts native `bool` (JSON), or `true`/`false`/
/// `1`/`0`/`yes`/`no`/`on`/`off` strings (forms).
class BoolField extends FormField<bool> {
  BoolField({
    required super.name,
    super.required = false,
    super.validators = const <FieldValidator<bool>>[],
  });

  @override
  bool parse(Object? raw) {
    if (raw is bool) return raw;
    if (raw is String) {
      switch (raw.trim().toLowerCase()) {
        case 'true':
        case '1':
        case 'yes':
        case 'on':
          return true;
        case 'false':
        case '0':
        case 'no':
        case 'off':
          return false;
      }
    }
    throw FormValidationException(errors: {name: 'Must be a boolean'});
  }
}

/// ISO 8601 date-time field.
class DateTimeField extends FormField<DateTime> {
  DateTimeField({
    required super.name,
    super.required = false,
    super.validators = const <FieldValidator<DateTime>>[],
  });

  @override
  DateTime parse(Object? raw) {
    if (raw is DateTime) return raw;
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed;
    }
    throw FormValidationException(
      errors: {name: 'Must be an ISO 8601 date/time'},
    );
  }
}

// ---------------------------------------------------------------------------
// Collection / file fields
// ---------------------------------------------------------------------------

/// Free-form JSON field (e.g. a nested object or array). The framework
/// only verifies that something was supplied; further structure
/// validation is up to the consumer.
class JsonField extends FormField<Object> {
  JsonField({
    required super.name,
    super.required = false,
    super.validators = const <FieldValidator<Object>>[],
  });

  @override
  Object parse(Object? raw) {
    if (raw == null) {
      throw FormValidationException(errors: {name: 'Expected a JSON value'});
    }
    return raw;
  }
}

/// Single-file upload field. Only meaningful for `multipart/form-data`
/// requests; for any other content type the field appears absent.
class FileField extends FormField<UploadedFile> {
  FileField({
    required super.name,
    super.required = false,
    super.validators = const <FieldValidator<UploadedFile>>[],
    this.allowedContentTypes,
    this.maxBytes,
  });

  /// Optional whitelist of MIME types (`'image/png'`, …). When
  /// supplied, uploads whose declared `Content-Type` is not in the set
  /// are rejected.
  final Set<String>? allowedContentTypes;

  /// Soft cap on the in-memory size of the upload. Enforcement only
  /// occurs if you call [UploadedFile.readAsBytes].
  final int? maxBytes;

  @override
  bool isAbsent(Object? raw) => raw == null;

  @override
  UploadedFile parse(Object? raw) {
    if (raw is! UploadedFile) {
      throw FormValidationException(
        errors: {name: 'Expected an uploaded file'},
      );
    }
    if (allowedContentTypes != null &&
        !allowedContentTypes!.contains(raw.contentType.mimeType)) {
      throw FormValidationException(errors: {
        name: 'Unsupported file type "${raw.contentType.mimeType}". '
            'Allowed: ${allowedContentTypes!.join(", ")}'
      });
    }
    return raw;
  }
}
