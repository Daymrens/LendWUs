import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/models/notification_item.dart';
import 'notification_service.dart';

class NotificationWatcher {
  final NotificationRepository _repository;
  StreamSubscription<List<NotificationItem>>? _subscription;
  String? _currentUserId;
  Set<String> _seenIds = {};

  NotificationWatcher({NotificationRepository? repository})
      : _repository = repository ?? NotificationRepository();

  void start(String userId) {
    if (_currentUserId == userId && _subscription != null) return;
    dispose();
    _currentUserId = userId;
    _seenIds = {};
    _subscription = _repository.streamNotifications(userId).listen((notifications) {
      final now = DateTime.now();
      for (final notification in notifications) {
        if (notification.id == null) continue;
        final createdAt = notification.createdAt;
        if (now.difference(createdAt).inSeconds > 5) {
          _seenIds.add(notification.id!);
        }
        if (!notification.read && !_seenIds.contains(notification.id!)) {
          _seenIds.add(notification.id!);
          debugPrint('NotificationWatcher: ${notification.title} — ${notification.body}');
          showLocalNotification(
            notification.title,
            notification.body,
            payload: notification.id,
          );
        }
      }
    });
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _currentUserId = null;
    _seenIds = {};
  }
}
