import '../../core/utils/firestore_helpers.dart';

class Member {
  String? id;
  String? memberId;
  String name;
  int headsCount;
  double amountPerHead;
  double totalRequired;
  double balance;
  double currentMonthTotal;
  String? currentMonthYear;
  String? avatarPath;
  DateTime joinedAt;
  bool isActive;
  String? linkedEmail;

  Member({
    this.id,
    this.memberId,
    required this.name,
    required this.headsCount,
    required this.amountPerHead,
    required this.totalRequired,
    this.balance = 0.0,
    this.currentMonthTotal = 0.0,
    this.currentMonthYear,
    this.avatarPath,
    required this.joinedAt,
    this.isActive = true,
    this.linkedEmail,
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
      'currentMonthTotal': currentMonthTotal,
      if (currentMonthYear != null) 'currentMonthYear': currentMonthYear,
      if (avatarPath != null) 'avatarPath': avatarPath,
      'joinedAt': joinedAt.toIso8601String(),
      'isActive': isActive,
      if (linkedEmail != null) 'linkedEmail': linkedEmail,
    };
  }

  factory Member.fromMap(Map<String, dynamic> map) {
    return Member(
      id: map['id'],
      memberId: map['memberId'],
      name: map['name'] ?? '',
      headsCount: map['headsCount'] ?? 1,
      amountPerHead: (map['amountPerHead'] as num?)?.toDouble() ?? 0.0,
      totalRequired: (map['totalRequired'] as num?)?.toDouble() ?? 0.0,
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
      currentMonthTotal: (map['currentMonthTotal'] as num?)?.toDouble() ?? 0.0,
      currentMonthYear: map['currentMonthYear'],
      avatarPath: map['avatarPath'],
      joinedAt: parseFirestoreDate(map['joinedAt']),
      isActive: map['isActive'] == true || map['isActive'] == 1,
      linkedEmail: map['linkedEmail'],
    );
  }
}
