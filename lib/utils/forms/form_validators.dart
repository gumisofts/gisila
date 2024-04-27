import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:project_mega/middlewares/common_middlewares.dart';
import 'package:project_mega/utils/utils.dart';

class Field<T> {
  Field({required this.name, required this.content});
  String name;
  T content;
}

class FieldValidator<T> {
  FieldValidator({
    required this.name,
    this.isRequired = false,
    this.validator,
  });
  String name;
  bool isRequired;
  String? Function(T value)? validator;

  String? validate(T value) {
    // final data = <String>[];
    if (validator == null) return null;

    return validator!(value);

    // for (final validator in validators) {
    //   final test = validator(value);
    //   if (test != null) {
    //     return test;
    //   }
    // }

    // return null;
  }
}

class EmailVerifier extends FieldValidator<String> {
  EmailVerifier({
    required super.name,
    super.isRequired = false,
    super.validator,
  });
}

final emailFieldValidator = FieldValidator<String>(
  name: 'email',
  validator: (value) {
    if (!RegExp(r'.+@.+\..{3}').hasMatch(value)) {
      return r'Invalid email format. use .+@.+\..{3}';
    }
    return null;
  },
);
final nameFieldValidator = FieldValidator<String>(
  name: 'name',
  validator: (value) {
    if (value.contains(' ')) {
      return 'This field should not contain spaces';
    }
    if (value.length > 255) {
      return 'This fields is to long limit 255 Char';
    }
    return null;
  },
);
Future<Map<String, dynamic>> form(
  RequestContext context, {
  required List<FieldValidator<dynamic>> fields,
}) async {
  final contentType = context.read<KContentType>();

  if (contentType case KContentType.json) {
    {
      final data = (await context.request.json()) as Map<String, dynamic>;

      final err = <String, dynamic>{};

      final validatedData = <String, dynamic>{};

      for (final field in fields) {
        if (field.isRequired && data[field.name] == null) {
          err[field.name] = 'This field is required';
          continue;
        }
        if (data[field.name] == null) {
          continue;
        }
        try {
          final validated = field.validate(data[field.name]);

          if (validated != null) {
            err[field.name] = validated;
          }
          if (data[field.name] != null) {
            validatedData[field.name] = data[field.name];
          }
        } catch (e) {
          err[field.name] = e.toString();
          continue;
        }
      }

      if (err.isNotEmpty) {
        throw FieldValidationException(error: err);
      }

      return validatedData;
    }
  } else if (contentType == KContentType.form ||
      contentType == KContentType.urlEncoded) {
    final formdata = await context.request.formData();

    final data = {...formdata.fields, ...formdata.files};

    final err = <String, dynamic>{};

    final validatedData = <String, dynamic>{};

    for (final field in fields) {
      if (field.isRequired && data[field.name] == null) {
        err[field.name] = 'This field is required';
        continue;
      }
      if (data[field.name] == null) {
        continue;
      }
      try {
        final validated = field.validate(data[field.name]);
        if (validated != null) {
          err[field.name] = validated;
        }
        if (data[field.name] != null) {
          validatedData[field.name] = data[field.name];
        }
      } catch (e) {
        err[field.name] = e.toString();
        continue;
      }
    }

    if (err.isNotEmpty) {
      throw FieldValidationException(error: err);
    }

    return validatedData;
  } else if (contentType case KContentType.plainText) {
    // context.request.body();
  }

  return {};
}
