enum UserRole { admin, member }

class User {
  String? id;
  String username;
  String email;
  String? password;
  UserRole role;
  String? memberId;
  String? photoUrl;
  String? fcmToken;
  DateTime createdAt;

  User({
    this.id,
    required this.username,
    required this.email,
    this.password,
    required this.role,
    this.memberId,
    this.photoUrl,
    this.fcmToken,
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
      'photoUrl': photoUrl,
      'fcmToken': fcmToken,
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
      photoUrl: map['photoUrl'],
      fcmToken: map['fcmToken'],
      createdAt: map['createdAt'] is DateTime
          ? map['createdAt']
          : DateTime.parse(map['createdAt']),
    );
  }
}
