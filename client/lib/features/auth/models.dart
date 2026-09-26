class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.role,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as int,
        name: json['name'] as String,
        email: json['email'] as String,
        role: json['role'] as String?,
      );

  final int id;
  final String name;
  final String email;
  final String? role;
}