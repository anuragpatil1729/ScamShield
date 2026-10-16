import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/message_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Can route to message detail when tapped
      },
    );

    // Request Android 13+ permission
    final androidImpl = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.requestNotificationsPermission();
    }

    _isInitialized = true;
  }

  /// Displays notification ONLY if the message is NOT SPAM.
  /// Spam and Sus messages are blocked from firing notifications to protect the user.
  Future<void> handleIncomingMessageNotification(MessageItem message) async {
    if (message.category != MessageCategory.notSpam) {
      // Per specification: Only not spam mails should be displayed on notifications.
      // Spam and suspicious items are silently quarantined in the ScamShield inbox.
      return;
    }

    await showSafeNotification(
      id: message.id.hashCode,
      sender: message.sender,
      body: message.snippet.isNotEmpty ? message.snippet : message.fullMessage,
    );
  }

  Future<void> showSafeNotification({
    required int id,
    required String sender,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'safe_mail_channel',
      'Verified Safe Messages',
      channelDescription: 'Notifications for verified and clean messages before opening',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _notificationsPlugin.show(
      id: id,
      title: 'Safe message from $sender',
      body: body,
      notificationDetails: notificationDetails,
    );
  }
}
