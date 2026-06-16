import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/notification_item.dart';
import '../../data/repositories/notification_repository.dart';
import '../../providers/notification_provider.dart';
import '../../providers/auth_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(currentUserProvider);
    final userId = auth.state?.id;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: Text('Not signed in')),
      );
    }

    final notificationsAsync = ref.watch(notificationStreamProvider(userId));

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(notificationStreamProvider(userId));
        },
        child: notificationsAsync.when(
          data: (notifications) {
            if (notifications.isEmpty) {
              return ListView(
                children:  [
                   SizedBox(height: 120),
                  Icon(Icons.notifications_off, size: 64, color: AppColors.textMuted),
                   SizedBox(height: 16),
                  Center(
                    child: Text('No notifications yet',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 16)),
                  ),
                ],
              );
            }
            return ListView.separated(
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return _NotificationTile(notification: notification);
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  final NotificationItem notification;

  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Icon(
        _iconForType(notification.type),
        color: notification.read ? AppColors.textMuted : AppColors.primary,
      ),
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight: notification.read ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: Text(
        notification.body,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: notification.read ? AppColors.textMuted : null,
        ),
      ),
      trailing: notification.read
          ? null
          : Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
      tileColor: notification.read ? null : AppColors.surfaceAlt,
      onTap: () {
        if (!notification.read && notification.id != null) {
          NotificationRepository().markAsRead(notification.id!);
        }
      },
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'payment':
        return Icons.payment;
      case 'loan':
        return Icons.account_balance;
      case 'approval':
        return Icons.check_circle;
      case 'head_change':
        return Icons.people_alt;
      case 'reminder':
        return Icons.notifications_active;
      case 'all_paid':
        return Icons.celebration;
      case 'system':
        return Icons.info;
      default:
        return Icons.notifications;
    }
  }
}
