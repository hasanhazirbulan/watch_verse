import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Must be a top-level (or static) function: the OS calls this in a separate
/// isolate when a push arrives while the app is backgrounded/terminated.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Nothing to do here yet — the OS already shows the notification for
  // background/terminated messages using the payload's `notification` block.
  // This handler exists so delivery doesn't crash; extend it if background
  // data-only messages need local processing (e.g. updating a badge count).
}

/// Push notifications: permission request, FCM token registration, and
/// foreground display via a local notification (FCM doesn't auto-show a
/// system notification while the app is in the foreground).
///
/// Wiring up who actually *sends* a notification (e.g. "someone followed
/// you", "a new episode aired") is a server-side concern — see
/// functions/src/index.ts for a Cloud Functions scaffold that reacts to the
/// relevant Firestore writes and calls the Admin SDK's messaging API.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _androidChannel = AndroidNotificationChannel(
    'watchverse_default',
    'General',
    description: 'Follows, comments, and episode updates.',
    importance: Importance.high,
  );

  /// firebase_messaging has no Linux/Windows implementation; skip there
  /// instead of throwing a MissingPluginException.
  bool get _isSupportedPlatform =>
      kIsWeb || Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  /// Requests permission, registers the FCM token for [uid], and starts
  /// listening for foreground/background messages. Safe to call once per
  /// signed-in session (e.g. from [AuthWrapper] once a user is available).
  Future<void> initialize(String uid) async {
    if (_initialized || !_isSupportedPlatform) return;
    _initialized = true;

    try {
      await _messaging.requestPermission(
          alert: true, badge: true, sound: true);

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);
      await _localNotifications.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );

      await _saveToken(uid);
      _messaging.onTokenRefresh.listen((_) => _saveToken(uid));

      FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler);
      FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    } catch (e) {
      // Permission denied, unsupported simulator, etc. — the app should
      // keep working without push; just don't retry until the next launch.
      debugPrint('NotificationService.initialize failed: $e');
    }
  }

  Future<void> _saveToken(String uid) async {
    final token = await _messaging.getToken();
    if (token == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'fcmToken': token});
    } catch (e) {
      debugPrint('Could not save FCM token: $e');
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  /// Clears the stored token on sign-out so a stale token doesn't linger on
  /// the user doc (best-effort — a `finally`-style cleanup, not critical).
  Future<void> clearToken(String uid) async {
    _initialized = false;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'fcmToken': FieldValue.delete()});
    } catch (_) {
      // Ignore — not worth surfacing a sign-out failure over this.
    }
  }
}
