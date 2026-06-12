import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/notification_item.dart';
import '../data/repositories/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

final notificationStreamProvider =
    StreamProvider.family.autoDispose<List<NotificationItem>, String>((ref, userId) {
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.streamNotifications(userId);
});

final unreadCountProvider =
    StreamProvider.family.autoDispose<int, String>((ref, userId) async* {
  final repo = ref.watch(notificationRepositoryProvider);
  final initial = await repo.getUnreadCount(userId);
  yield initial;
  await for (final notifications in repo.streamNotifications(userId)) {
    yield notifications.where((n) => !n.read).length;
  }
});

final deleteNotificationProvider =
    FutureProvider.family<void, String>((ref, notificationId) async {
  final repo = ref.watch(notificationRepositoryProvider);
  await repo.deleteNotification(notificationId);
  ref.invalidate(notificationStreamProvider);
});

final deleteAllNotificationsProvider =
    FutureProvider.family<void, String>((ref, userId) async {
  final repo = ref.watch(notificationRepositoryProvider);
  await repo.deleteAllNotifications(userId);
  ref.invalidate(notificationStreamProvider);
});

final deleteReadNotificationsProvider =
    FutureProvider.family<void, String>((ref, userId) async {
  final repo = ref.watch(notificationRepositoryProvider);
  await repo.deleteReadNotifications(userId);
  ref.invalidate(notificationStreamProvider);
});
