import '../../core/utils/firestore_helpers.dart';

class Member {
  String? id;
  String? memberId;
  String name;
  int headsCount;
  int amountPerHead;
  int totalRequired;
  int balance;
  String? avatarPath;
  DateTime joinedAt;
  bool isActive;
  String? linkedEmail;
  String? contactNumber;

  Member({
    this.id,
    this.memberId,
    required this.name,
    required this.headsCount,
    required this.amountPerHead,
    required this.totalRequired,
    this.balance = 0,
    this.avatarPath,
    required this.joinedAt,
    this.isActive = true,
    this.linkedEmail,
    this.contactNumber,
  });

  String get displayId => memberId ?? id ?? '';

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (memberId != null) 'memberId': memberId,
      'name': name,
      'headsCount': headsCount,
      'amountPerHead': amountPerHead,
      'totalRequired': totalRequired,
      'balance': balance,
      if (avatarPath != null) 'avatarPath': avatarPath,
      'joinedAt': joinedAt.toIso8601String(),
      'isActive': isActive,
      if (linkedEmail != null) 'linkedEmail': linkedEmail,
      if (contactNumber != null) 'contactNumber': contactNumber,
    };
  }

  factory Member.fromMap(Map<String, dynamic> map) {
    return Member(
      id: map['id'],
      memberId: map['memberId'],
      name: map['name'] ?? '',
      headsCount: map['headsCount'] ?? 1,
      amountPerHead: (map['amountPerHead'] as num?)?.toInt() ?? 0,
      totalRequired: (map['totalRequired'] as num?)?.toInt() ?? 0,
      balance: (map['balance'] as num?)?.toInt() ?? 0,
      avatarPath: map['avatarPath'],
      joinedAt: parseFirestoreDate(map['joinedAt']),
      isActive: map['isActive'] != false,
      linkedEmail: map['linkedEmail'],
      contactNumber: map['contactNumber'],
    );
  }
}
