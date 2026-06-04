enum HeadChangeStatus { pending, approved, rejected }

class HeadChangeRequest {
  String? id;
  String memberId;
  String memberName;
  int currentHeads;
  int requestedHeads;
  String? reason;
  HeadChangeStatus status;
  DateTime requestedAt;
  DateTime? processedAt;
  String? processedBy;
  String? notes;

  HeadChangeRequest({
    this.id,
    required this.memberId,
    required this.memberName,
    required this.currentHeads,
    required this.requestedHeads,
    this.reason,
    this.status = HeadChangeStatus.pending,
    required this.requestedAt,
    this.processedAt,
    this.processedBy,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'memberId': memberId,
      'memberName': memberName,
      'currentHeads': currentHeads,
      'requestedHeads': requestedHeads,
      'reason': reason,
      'status': status.name,
      'requestedAt': requestedAt.toIso8601String(),
      'processedAt': processedAt?.toIso8601String(),
      'processedBy': processedBy,
      'notes': notes,
    };
  }

  factory HeadChangeRequest.fromMap(Map<String, dynamic> map) {
    return HeadChangeRequest(
      id: map['id'],
      memberId: map['memberId'],
      memberName: map['memberName'],
      currentHeads: (map['currentHeads'] as num).toInt(),
      requestedHeads: (map['requestedHeads'] as num).toInt(),
      reason: map['reason'],
      status: HeadChangeStatus.values.firstWhere((e) => e.name == map['status']),
      requestedAt: map['requestedAt'] is DateTime
          ? map['requestedAt']
          : DateTime.parse(map['requestedAt']),
      processedAt: map['processedAt'] != null
          ? (map['processedAt'] is DateTime
              ? map['processedAt']
              : DateTime.parse(map['processedAt']))
          : null,
      processedBy: map['processedBy'],
      notes: map['notes'],
    );
  }
}
