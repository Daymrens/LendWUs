import '../../core/firebase/firebase_service.dart';

class ActivityLogRepository {
  Future<void> logActivity({
    required String action,
    required String entityType,
    String? entityId,
    String? performedBy,
    String? performedByName,
    Map<String, dynamic>? details,
  }) async {
    await FirebaseService.firestore.collection('activity_log').add({
      'action': action,
      'entityType': entityType,
      'entityId': entityId,
      'performedBy': performedBy,
      'performedByName': performedByName,
      'details': details,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }
}
