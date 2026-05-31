/// Typed form / input validation layer.
///
/// User code declares a [Form] subclass with one [FormField] per
/// expected request input; the framework parses, validates, and hands
/// the controller a fully populated typed instance.
///
/// Quick start:
///
/// ```dart
/// class RegisterForm extends Form {
///   final email     = EmailField(required: true);
///   final password  = PasswordField(required: true);
///   final firstName = StringField(name: 'firstName');
///
///   @override
///   List<FormField<Object?>> collectFields() =>
///       [email, password, firstName];
/// }
///
/// @Post('/register')
/// Future<User> register(RegisterForm form, AuthService svc) =>
///     svc.register(form.email.value!, form.password.value!);
/// ```
///
/// The generator detects [Form]-subtype parameters and emits a call to
/// [bindForm] under the hood, so no `await form(request, fields: [...])`
/// boilerplate is needed in the controller.
library gisila.runtime.forms;

export 'forms/fields.dart';
export 'forms/form.dart';
