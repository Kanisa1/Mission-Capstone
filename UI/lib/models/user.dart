enum UserRole {
  inspector,
  regulator,
  admin,
}

class User {
  final String id;
  final String email;
  final String name;
  final UserRole role;
  final String? profilePicture;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.profilePicture,
  });
}
