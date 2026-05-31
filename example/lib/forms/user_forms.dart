/// Typed input forms for the users API.
///
/// Each [Form] subclass declares one [FormField] per expected request
/// input. The framework parses + validates + populates them before the
/// controller method runs; the controller reads typed `fieldName.value`
/// and never touches the raw request body.
library;

import 'package:gisila/gisila.dart';

class RegisterForm extends Form {
  final email = EmailField(name: 'email', required: true);
  final password = PasswordField(name: 'password', required: true);
  final name = StringField(name: 'name', required: true, maxLength: 100);

  @override
  List<FormField<Object?>> collectFields() => [email, password, name];
}

class LoginForm extends Form {
  final email = EmailField(name: 'email', required: true);
  final password = StringField(name: 'password', required: true);

  /// Optional "remember me" toggle. HTML clients submit this as
  /// `"on"`/`"true"`; JSON clients send a real boolean - the framework
  /// handles both via [BoolField.parse].
  final remember = BoolField(name: 'remember');

  @override
  List<FormField<Object?>> collectFields() => [email, password, remember];
}

class UpdateUserForm extends Form {
  final name = StringField(name: 'name', maxLength: 100);
  final email = EmailField(name: 'email');

  @override
  List<FormField<Object?>> collectFields() => [name, email];
}
