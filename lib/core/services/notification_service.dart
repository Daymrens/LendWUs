import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const _channelId = 'sinking_fund_notifications';
const _channelName = 'Sinking Fund Notifications';
const _channelDescription = 'Payment, loan, and head change notifications';

final FlutterLocalNotificationsPlugin _localPlugin = FlutterLocalNotificationsPlugin();
final GlobalKey<NavigatorState> notificationNavKey = GlobalKey<NavigatorState>();
bool _foregroundListenerInstalled = false;

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final notification = message.notification;
  if (notification != null) {
    await showLocalNotification(notification.title ?? '', notification.body ?? '');
  }
}

Future<void> showLocalNotification(String title, String body, {String? payload}) async {
  await _localPlugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    ),
    payload: payload,
  );
}

class NotificationService {
  static FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  static Future<void> init() async {
    await requestPermission();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localPlugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
    );
    await _localPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    if (!_foregroundListenerInstalled) {
      _foregroundListenerInstalled = true;
      FirebaseMessaging.onMessage.listen((message) {
        final notification = message.notification;
        if (notification != null) {
          showLocalNotification(notification.title ?? '', notification.body ?? '');
        }
      });
    }
  }

  static void _onNotificationTap(NotificationResponse response) {
    final nav = notificationNavKey.currentContext;
    if (nav != null) {
      GoRouter.of(nav).push('/notifications');
    }
  }

  static Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    debugPrint('Notification permission: ${settings.authorizationStatus}');
    return granted;
  }

  static Future<String?> getFcmToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('FCM token error: $e');
      return null;
    }
  }

  static Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;
}
