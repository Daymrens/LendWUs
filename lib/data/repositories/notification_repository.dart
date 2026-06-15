import '../models/notification_item.dart';
import '../../core/firebase/firebase_service.dart';

class NotificationRepository {
  static Future<void> _notifyUsers(
    List<String> userIds,
    String title,
    String body,
    String type,
    Map<String, dynamic>? data,
  ) async {
    final now = DateTime.now().toIso8601String();
    final batch = FirebaseService.firestore.batch();
    for (final uid in userIds) {
      final docRef = FirebaseService.firestore.collection('notifications').doc();
      batch.set(docRef, {
        'userId': uid,
        'title': title,
        'body': body,
        'type': type,
        'data': data,
        'read': false,
        'createdAt': now,
      });
    }
    await batch.commit();
  }

  static Future<void> notifyAdmins(
    String title,
    String body, {
    String? type,
    Map<String, dynamic>? data,
  }) async {
    final adminSnapshot = await FirebaseService.firestore
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .get();
    if (adminSnapshot.docs.isEmpty) return;
    final adminIds = adminSnapshot.docs.map((d) => d.id).toList();
    await _notifyUsers(adminIds, title, body, type ?? '', data);
  }

  static Future<void> notifyTreasurers(
    String title,
    String body, {
    String? type,
    Map<String, dynamic>? data,
  }) async {
    final treasurerSnapshot = await FirebaseService.firestore
        .collection('users')
        .where('isTreasurer', isEqualTo: true)
        .get();
    if (treasurerSnapshot.docs.isEmpty) return;
    final treasurerIds = treasurerSnapshot.docs.map((d) => d.id).toList();
    await _notifyUsers(treasurerIds, title, body, type ?? '', data);
  }

  static Future<void> notifyByIds(
    List<String> userIds,
    String title,
    String body, {
    String? type,
    Map<String, dynamic>? data,
  }) async {
    await _notifyUsers(userIds, title, body, type ?? '', data);
  }

  static Future<void> notifyAll(
    String title,
    String body, {
    String? type,
    Map<String, dynamic>? data,
  }) async {
    final allUsersSnapshot = await FirebaseService.firestore
        .collection('users')
        .get();
    if (allUsersSnapshot.docs.isEmpty) return;
    final allIds = allUsersSnapshot.docs.map((d) => d.id).toList();
    await _notifyUsers(allIds, title, body, type ?? '', data);
  }

  static Future<void> notifyAllMembers(
    String title,
    String body, {
    String? type,
    Map<String, dynamic>? data,
  }) async {
    final memberSnapshot = await FirebaseService.firestore
        .collection('users')
        .where('role', isEqualTo: 'member')
        .get();
    if (memberSnapshot.docs.isEmpty) return;
    final memberIds = memberSnapshot.docs.map((d) => d.id).toList();
    await _notifyUsers(memberIds, title, body, type ?? '', data);
  }

  static Future<void> notifyMember(
    String memberId,
    String title,
    String body, {
    String? type,
    Map<String, dynamic>? data,
  }) async {
    final userSnapshot = await FirebaseService.firestore
        .collection('users')
        .where('memberId', isEqualTo: memberId)
        .limit(1)
        .get();
    if (userSnapshot.docs.isEmpty) return;
    await _notifyUsers(
      [userSnapshot.docs.first.id],
      title,
      body,
      type ?? '',
      data,
    );
  }

  Future<void> addNotification(NotificationItem notification) async {
    await FirebaseService.firestore.collection('notifications').add(notification.toMap());
  }

  Stream<List<NotificationItem>> streamNotifications(String userId) {
    return FirebaseService.firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationItem.fromMap({...doc.data(), 'id': doc.id}))
            .toList());
  }

  Future<void> markAsRead(String notificationId) async {
    await FirebaseService.firestore
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }

  Future<void> deleteNotification(String notificationId) async {
    await FirebaseService.firestore
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }

  Future<void> deleteAllNotifications(String userId) async {
    final snapshot = await FirebaseService.firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .get();
    final batch = FirebaseService.firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> deleteReadNotifications(String userId) async {
    final snapshot = await FirebaseService.firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: true)
        .get();
    final batch = FirebaseService.firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<int> getUnreadCount(String userId) async {
    final snapshot = await FirebaseService.firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();
    return snapshot.docs.length;
  }
}
