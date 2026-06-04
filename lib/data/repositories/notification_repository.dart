import '../models/notification_item.dart';
import '../../core/firebase/firebase_service.dart';

class NotificationRepository {
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

  Future<int> getUnreadCount(String userId) async {
    final snapshot = await FirebaseService.firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();
    return snapshot.docs.length;
  }
}
