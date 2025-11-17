import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static const String _androidChannelId = 'quran_channel';
  static const String _androidChannelName = 'Recitation Alerts';
  static const String _androidChannelDescription =
      'Weekly Qur\'an assignments and community updates.';

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
        _androidChannelId,
        _androidChannelName,
        description: _androidChannelDescription,
        importance: Importance.high,
      );

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    if (!kIsWeb) {
      await _fcm.requestPermission();

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const darwinSettings = DarwinInitializationSettings();

      const initializationSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );

      await _localNotifications.initialize(initializationSettings);

      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.createNotificationChannel(_androidChannel);
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        showLocalNotification(
          notification.title ?? 'Recitation Update',
          notification.body ?? '',
        );
      }
    });

    final platform = defaultTargetPlatform;
    if (!kIsWeb &&
        (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS)) {
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  Future<void> subscribeToCommunityTopic() async {
    if (kIsWeb) {
      return;
    }
    await _fcm.subscribeToTopic('community');
  }

  Future<void> unsubscribeFromCommunityTopic() async {
    if (kIsWeb) {
      return;
    }
    await _fcm.unsubscribeFromTopic('community');
  }

  Future<void> subscribeToGroupTopic(String groupId) async {
    if (kIsWeb) {
      return;
    }
    await _fcm.subscribeToTopic('group_$groupId');
  }

  Future<void> unsubscribeFromGroupTopic(String groupId) async {
    if (kIsWeb) {
      return;
    }
    await _fcm.unsubscribeFromTopic('group_$groupId');
  }

  Future<void> unsubscribeFromAllTopics() async {
    if (kIsWeb) {
      return;
    }
    await _fcm.deleteToken();
  }

  Future<String?> getDeviceToken() async {
    if (kIsWeb) {
      return null;
    }
    return _fcm.getToken();
  }

  Future<void> showLocalNotification(String title, String body) async {
    if (kIsWeb) {
      return;
    }
    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannelId,
        _androidChannelName,
        channelDescription: _androidChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
    );
  }
}
