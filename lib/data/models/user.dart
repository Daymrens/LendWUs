import '../../core/utils/firestore_helpers.dart';

enum UserRole { admin, member }

class User {
  String? id;
  String username;
  String email;
  UserRole role;
  String? memberId; // This is the doc ID
  String? displayId; // This is the LWS format ID
  String? photoUrl;
  String? fcmToken;
  bool isTreasurer;
  DateTime createdAt;

  User({
    this.id,
    required this.username,
    required this.email,
    required this.role,
    this.memberId,
    this.displayId,
    this.photoUrl,
    this.fcmToken,
    this.isTreasurer = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'username': username,
      'email': email,
      'role': role.name,
      'memberId': memberId,
      'displayId': displayId,
      'photoUrl': photoUrl,
      'fcmToken': fcmToken,
      'isTreasurer': isTreasurer,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      username: map['username'] ?? '',
      email: map['email'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.name.toLowerCase() == map['role'].toString().toLowerCase(),
        orElse: () => UserRole.member,
      ),
      memberId: map['memberId'],
      displayId: map['displayId'],
      photoUrl: map['photoUrl'],
      fcmToken: map['fcmToken'],
      isTreasurer: map['isTreasurer'] ?? false,
      createdAt: parseFirestoreDate(map['createdAt']),
    );
  }
}
