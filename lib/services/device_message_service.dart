import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DeviceMessageService {
  static const MethodChannel _methodChannel =
      MethodChannel('com.scamshield/device_messages');
  static const EventChannel _eventChannel =
      EventChannel('com.scamshield/incoming_messages');

  static final DeviceMessageService _instance =
      DeviceMessageService._internal();
  factory DeviceMessageService() => _instance;
  DeviceMessageService._internal();

  Stream<Map<String, dynamic>>? _incomingStream;

  /// Check if READ_SMS and RECEIVE_SMS permissions are granted
  Future<bool> hasSmsPermission() async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('hasSmsPermission');
      return res ?? false;
    } catch (e) {
      debugPrint('hasSmsPermission error: $e');
      return false;
    }
  }

  /// Request runtime SMS permissions from the user
  Future<bool> requestSmsPermission() async {
    try {
      final res =
          await _methodChannel.invokeMethod<bool>('requestSmsPermission');
      return res ?? false;
    } catch (e) {
      debugPrint('requestSmsPermission error: $e');
      return false;
    }
  }

  /// Check if ScamShield has NotificationListenerService access enabled in Android settings
  Future<bool> hasNotificationAccess() async {
    try {
      final res =
          await _methodChannel.invokeMethod<bool>('hasNotificationAccess');
      return res ?? false;
    } catch (e) {
      debugPrint('hasNotificationAccess error: $e');
      return false;
    }
  }

  /// Open Android Notification Access settings so user can enable ScamShield
  Future<bool> requestNotificationAccess() async {
    try {
      final res =
          await _methodChannel.invokeMethod<bool>('requestNotificationAccess');
      return res ?? false;
    } catch (e) {
      debugPrint('requestNotificationAccess error: $e');
      return false;
    }
  }

  /// Read existing SMS messages from Android's default messaging app database
  Future<List<Map<String, dynamic>>> readDeviceSmsInbox(
      {int limit = 100}) async {
    try {
      final hasPerm = await hasSmsPermission();
      if (!hasPerm) {
        final granted = await requestSmsPermission();
        if (!granted) return [];
      }

      final List<dynamic>? raw = await _methodChannel.invokeMethod(
        'readSmsInbox',
        {'limit': limit},
      );

      if (raw == null) return [];
      return raw.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } catch (e) {
      debugPrint('readDeviceSmsInbox error: $e');
      return [];
    }
  }

  /// Dismiss/cancel a notification from the Android status bar if detected as SPAM
  Future<bool> dismissSpamNotification(String notificationKey) async {
    if (notificationKey.isEmpty) return false;
    try {
      final res = await _methodChannel.invokeMethod<bool>(
        'dismissNotification',
        {'notificationKey': notificationKey},
      );
      return res ?? false;
    } catch (e) {
      debugPrint('dismissSpamNotification error: $e');
      return false;
    }
  }

  /// Real-time stream of incoming messages (SMS broadcast or intercepted notifications)
  Stream<Map<String, dynamic>> get incomingMessages {
    _incomingStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => Map<String, dynamic>.from(event as Map));
    return _incomingStream!;
  }
}
