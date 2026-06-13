import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Thin wrapper around `flutter_local_notifications` for surfacing gateway
/// alerts as real OS notifications while the app is running or backgrounded.
///
/// Closed-app push (delivered when the process is killed) additionally needs
/// FCM (Android) + APNs (iOS) — wire those keys later; this class is the
/// on-device presentation layer both paths share.
class LocalNotifications {
  LocalNotifications._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _inited = false;
  static bool _available = true;

  static Future<void> init() async {
    if (_inited || !_available) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      await _plugin.initialize(
        const InitializationSettings(
          android: android,
          iOS: darwin,
          macOS: darwin,
        ),
      );
      // Android 13+ runtime permission.
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _inited = true;
    } catch (e) {
      // Unsupported platform / no plugin (e.g. unit tests) → degrade silently.
      _available = false;
      if (kDebugMode) debugPrint('LocalNotifications unavailable: $e');
    }
  }

  static Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_available) return;
    await init();
    if (!_inited) return;
    try {
      const android = AndroidNotificationDetails(
        'alerts',
        'Plug alerts',
        channelDescription: 'Offline, idle auto-off and schedule events',
        importance: Importance.high,
        priority: Priority.high,
      );
      const darwin = DarwinNotificationDetails();
      await _plugin.show(
        id,
        title,
        body,
        const NotificationDetails(android: android, iOS: darwin, macOS: darwin),
      );
    } catch (_) {
      // best-effort
    }
  }
}
