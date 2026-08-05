import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:watch_verse/models/media.dart';
import 'package:watch_verse/screens/friends_activity_screen.dart';
import 'package:watch_verse/screens/public_profile_screen.dart';
import 'package:watch_verse/utils/navigation.dart';

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
  GlobalKey<NavigatorState>? _navigatorKey;

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
  /// [navigatorKey] is used to route a tapped notification to the relevant
  /// screen (see [_handleTap]) without needing a BuildContext at the call
  /// site — pass the same key the app's root `MaterialApp` uses.
  Future<void> initialize(String uid,
      {GlobalKey<NavigatorState>? navigatorKey}) async {
    _navigatorKey = navigatorKey;
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

      // Tapped while backgrounded, and tapped from a cold start respectively.
      FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
      final initial = await _messaging.getInitialMessage();
      if (initial != null) _handleTap(initial);
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

  /// Routes a tapped notification to the relevant screen, using the `data`
  /// payload the Cloud Function attached (see functions/src/index.ts) — no
  /// extra network round-trip before navigating, since the function already
  /// includes the title/poster it needs. Silently no-ops for unknown/legacy
  /// payloads (e.g. an old `type: 'activity'` push still in the tray from
  /// before the digest system existed).
  void _handleTap(RemoteMessage message) {
    final nav = _navigatorKey?.currentState;
    if (nav == null) return;
    final data = message.data;

    switch (data['type']) {
      case 'follow':
        nav.push(MaterialPageRoute(
          builder: (_) => PublicProfileScreen(
              userId: data['actorUid'] ?? '', name: data['actorName'] ?? ''),
        ));
        return;
      case 'activity-digest':
        nav.push(
            MaterialPageRoute(builder: (_) => const FriendsActivityScreen()));
        return;
      case 'episode-tomorrow':
      case 'episode-today':
      case 'shared-watch':
        final id = int.tryParse(data['id'] ?? '');
        if (id == null) return;
        openMedia(
          nav.context,
          MediaItem(
            id: id,
            title: data['title'] ?? '',
            overview: '',
            posterPath: data['posterPath'] ?? '',
            backdropPath: '',
            date: '',
            voteAverage: 0,
            mediaType:
                data['mediaType'] == 'movie' ? MediaType.movie : MediaType.tv,
          ),
        );
        return;
    }
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
