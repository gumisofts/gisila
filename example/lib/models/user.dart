/// Plain DTOs used by the example app.
///
/// `User` is the "model" the in-memory repository persists; the form
/// classes (`RegisterForm`, `LoginForm`, `UpdateUserForm`) live next
/// to the controllers under `forms/`.
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
