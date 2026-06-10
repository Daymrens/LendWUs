import '../../core/utils/firestore_helpers.dart';

class ActivityLog {
  String? id;
  String action;
  String entityType;
  String? entityId;
  String? performedBy;
  String? performedByName;
  Map<String, dynamic>? details;
  DateTime createdAt;

  ActivityLog({
    this.id,
    required this.action,
    required this.entityType,
    this.entityId,
    this.performedBy,
    this.performedByName,
    this.details,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'action': action,
      'entityType': entityType,
      'entityId': entityId,
      'performedBy': performedBy,
      'performedByName': performedByName,
      'details': details,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ActivityLog.fromMap(Map<String, dynamic> map) {
    return ActivityLog(
      id: map['id'],
      action: map['action'] ?? '',
      entityType: map['entityType'] ?? '',
      entityId: map['entityId'],
      performedBy: map['performedBy'],
      performedByName: map['performedByName'],
      details: map['details'] is Map<String, dynamic> ? map['details'] : null,
      createdAt: parseFirestoreDate(map['createdAt']),
    );
  }
}
