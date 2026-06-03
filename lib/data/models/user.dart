enum UserRole { admin, member }

class User {
  String? id;
  String username;
  String email;
  String? password;
  UserRole role;
  String? memberId;
  DateTime createdAt;

  User({
    this.id,
    required this.username,
    required this.email,
    this.password,
    required this.role,
    this.memberId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'username': username,
      'email': email,
      'password': password,
      'role': role.name,
      'memberId': memberId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      username: map['username'],
      email: map['email'] ?? '',
      password: map['password'],
      role: UserRole.values.firstWhere(
        (e) => e.name.toLowerCase() == map['role'].toString().toLowerCase(),
        orElse: () => UserRole.member,
      ),
      memberId: map['memberId'],
      createdAt: map['createdAt'] is DateTime
          ? map['createdAt']
          : DateTime.parse(map['createdAt']),
    );
  }
}
