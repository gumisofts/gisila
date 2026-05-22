class User {
  User({
    required this.id,
    required this.name,
    required this.email,
    this.roles = const <String>{},
  });

  final String id;
  final String name;
  final String email;
  final Set<String> roles;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'email': email,
        'roles': roles.toList(),
      };
}

class CreateUser {
  CreateUser({required this.name, required this.email, this.roles = const {}});

  factory CreateUser.fromJson(Map<String, dynamic> json) => CreateUser(
        name: json['name'] as String,
        email: json['email'] as String,
        roles: (json['roles'] as List?)?.cast<String>().toSet() ?? const {},
      );

  final String name;
  final String email;
  final Set<String> roles;
}

/// Demonstrates dual-shape parsing. `fromForm` is called when the
/// caller sends `application/x-www-form-urlencoded` (or
/// `multipart/form-data`); `fromJson` is the fallback for
/// `application/json`. The framework prefers `fromForm` when both
/// exist, since it can correctly coerce string-only form values into
/// the expected Dart types.
class LoginForm {
  LoginForm({required this.username, this.remember = false});

  factory LoginForm.fromJson(Map<String, dynamic> json) => LoginForm(
        username: json['username'] as String,
        remember: (json['remember'] as bool?) ?? false,
      );

  factory LoginForm.fromForm(Map<String, dynamic> form) => LoginForm(
        username: form['username'] as String,
        remember: switch (form['remember']) {
          'true' || '1' || 'yes' || 'on' => true,
          _ => false,
        },
      );

  final String username;
  final bool remember;
}
