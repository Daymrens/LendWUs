import '../../core/utils/firestore_helpers.dart';

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
      memberId: map['memberId'] ?? '',
      memberName: map['memberName'] ?? 'Unknown',
      currentHeads: (map['currentHeads'] as num?)?.toInt() ?? 0,
      requestedHeads: (map['requestedHeads'] as num?)?.toInt() ?? 0,
      reason: map['reason'],
      status: HeadChangeStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => HeadChangeStatus.pending,
      ),
      requestedAt: parseFirestoreDate(map['requestedAt']),
      processedAt: parseFirestoreDateOrNull(map['processedAt']),
      processedBy: map['processedBy'],
      notes: map['notes'],
    );
  }
}
