class Member {
  String? id;
  String name;
  int headsCount;
  double amountPerHead;
  double totalRequired;
  double balance;
  String? avatarPath;
  DateTime joinedAt;
  bool isActive;
  String? linkedEmail;

  Member({
    this.id,
    required this.name,
    required this.headsCount,
    required this.amountPerHead,
    required this.totalRequired,
    this.balance = 0.0,
    this.avatarPath,
    required this.joinedAt,
    this.isActive = true,
    this.linkedEmail,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'headsCount': headsCount,
      'amountPerHead': amountPerHead,
      'totalRequired': totalRequired,
      'balance': balance,
      'avatarPath': avatarPath,
      'joinedAt': joinedAt.toIso8601String(),
      'isActive': isActive,
      'linkedEmail': linkedEmail,
    };
  }

  factory Member.fromMap(Map<String, dynamic> map) {
    return Member(
      id: map['id'],
      name: map['name'],
      headsCount: map['headsCount'],
      amountPerHead: (map['amountPerHead'] as num).toDouble(),
      totalRequired: (map['totalRequired'] as num).toDouble(),
      balance: (map['balance'] ?? 0.0).toDouble(),
      avatarPath: map['avatarPath'],
      joinedAt: map['joinedAt'] is DateTime
          ? map['joinedAt']
          : DateTime.parse(map['joinedAt']),
      isActive: map['isActive'] == true || map['isActive'] == 1,
      linkedEmail: map['linkedEmail'],
    );
  }
}
