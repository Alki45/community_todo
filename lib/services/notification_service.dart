import 'package:firebase_core/firebase_core.dart';
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

  FirebaseMessaging? _fcm;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool get _isFirebaseAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  FirebaseMessaging? get _fcmInstance {
    if (!_isFirebaseAvailable) {
      return null;
    }
    try {
      return _fcm ??= FirebaseMessaging.instance;
    } catch (_) {
      return null;
    }
  }

  Future<void> init() async {
    if (!kIsWeb) {
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

    // Only initialize Firebase Messaging if Firebase is available
    final fcm = _fcmInstance;
    if (fcm != null) {
      try {
        await fcm.requestPermission();
      } catch (e) {
        debugPrint('Firebase Messaging permission request failed: $e');
      }

      try {
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          final notification = message.notification;
          if (notification != null) {
            showLocalNotification(
              notification.title ?? 'Recitation Update',
              notification.body ?? '',
            );
          }
        });
      } catch (e) {
        debugPrint('Firebase Messaging onMessage listener setup failed: $e');
      }

      final platform = defaultTargetPlatform;
      if (!kIsWeb &&
          (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS)) {
        try {
          await fcm.setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );
        } catch (e) {
          debugPrint('Firebase Messaging foreground options setup failed: $e');
        }
      }
    }
  }

  Future<void> subscribeToCommunityTopic() async {
    if (kIsWeb) {
      return;
    }
    final fcm = _fcmInstance;
    if (fcm != null) {
      try {
        await fcm.subscribeToTopic('community');
      } catch (e) {
        debugPrint('Failed to subscribe to community topic: $e');
      }
    }
  }

  Future<void> unsubscribeFromCommunityTopic() async {
    if (kIsWeb) {
      return;
    }
    final fcm = _fcmInstance;
    if (fcm != null) {
      try {
        await fcm.unsubscribeFromTopic('community');
      } catch (e) {
        debugPrint('Failed to unsubscribe from community topic: $e');
      }
    }
  }

  Future<void> subscribeToGroupTopic(String groupId) async {
    if (kIsWeb) {
      return;
    }
    final fcm = _fcmInstance;
    if (fcm != null) {
      try {
        await fcm.subscribeToTopic('group_$groupId');
      } catch (e) {
        debugPrint('Failed to subscribe to group topic: $e');
      }
    }
  }

  Future<void> unsubscribeFromGroupTopic(String groupId) async {
    if (kIsWeb) {
      return;
    }
    final fcm = _fcmInstance;
    if (fcm != null) {
      try {
        await fcm.unsubscribeFromTopic('group_$groupId');
      } catch (e) {
        debugPrint('Failed to unsubscribe from group topic: $e');
      }
    }
  }

  Future<void> unsubscribeFromAllTopics() async {
    if (kIsWeb) {
      return;
    }
    final fcm = _fcmInstance;
    if (fcm != null) {
      try {
        await fcm.deleteToken();
      } catch (e) {
        debugPrint('Failed to delete FCM token: $e');
      }
    }
  }

  Future<String?> getDeviceToken() async {
    if (kIsWeb) {
      return null;
    }
    final fcm = _fcmInstance;
    if (fcm != null) {
      try {
        return await fcm.getToken();
      } catch (e) {
        debugPrint('Failed to get FCM token: $e');
        return null;
      }
    }
    return null;
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
