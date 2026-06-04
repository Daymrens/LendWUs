import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/notification_item.dart';
import '../data/repositories/notification_repository.dart';

final notificationStreamProvider = StreamProvider.family.autoDispose<List<NotificationItem>, String>((ref, userId) {
  final repo = NotificationRepository();
  return repo.streamNotifications(userId);
});

final unreadCountProvider = StreamProvider.family.autoDispose<int, String>((ref, userId) async* {
  final repo = NotificationRepository();
  final initial = await repo.getUnreadCount(userId);
  yield initial;
  await for (final notifications in repo.streamNotifications(userId)) {
    yield notifications.where((n) => !n.read).length;
  }
});
