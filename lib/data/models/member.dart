class Member {
  String? id;
  String name;
  int headsCount;
  double amountPerHead;
  double totalRequired;
  String? avatarPath;
  DateTime joinedAt;
  bool isActive;

  Member({
    this.id,
    required this.name,
    required this.headsCount,
    required this.amountPerHead,
    required this.totalRequired,
    this.avatarPath,
    required this.joinedAt,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'headsCount': headsCount,
      'amountPerHead': amountPerHead,
      'totalRequired': totalRequired,
      'avatarPath': avatarPath,
      'joinedAt': joinedAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory Member.fromMap(Map<String, dynamic> map) {
    return Member(
      id: map['id'],
      name: map['name'],
      headsCount: map['headsCount'],
      amountPerHead: (map['amountPerHead'] as num).toDouble(),
      totalRequired: (map['totalRequired'] as num).toDouble(),
      avatarPath: map['avatarPath'],
      joinedAt: map['joinedAt'] is DateTime
          ? map['joinedAt']
          : DateTime.parse(map['joinedAt']),
      isActive: map['isActive'] == true || map['isActive'] == 1,
    );
  }
}
