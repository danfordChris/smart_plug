import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../config/constants.dart';
import 'notifications.dart';

/// Background isolate handler. Must be a top-level function. FCM displays
/// `notification`-type messages automatically when the app is backgrounded or
/// killed, so there's nothing to do here — but it must be registered.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Firebase Cloud Messaging integration: requests permission, registers the
/// device token with the gateway, and presents foreground messages as local
/// notifications. All entry points degrade to no-ops if Firebase failed to
/// initialise (e.g. unsupported platform), so callers never need to guard.
class PushService {
  PushService._();

  static bool _enabled = false;
  static String? _gatewayUrl;
  static String? _accessToken;

  /// Call once at startup AFTER Firebase.initializeApp.
  static Future<void> init() async {
    try {
      final fm = FirebaseMessaging.instance;
      await fm.requestPermission();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        if (n != null) {
          LocalNotifications.show(
            id: m.hashCode & 0x7fffffff,
            title: n.title ?? 'Smart Power',
            body: n.body ?? '',
          );
        }
      });
      fm.onTokenRefresh.listen(_sendToken);
      _enabled = true;
    } catch (e) {
      _enabled = false;
      if (kDebugMode) debugPrint('PushService disabled: $e');
    }
  }

  /// Associate the current FCM token with a signed-in session on the gateway.
  static Future<void> registerWith(String gatewayUrl, String accessToken) async {
    _gatewayUrl = gatewayUrl;
    _accessToken = accessToken;
    if (!_enabled) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _sendToken(token);
    } catch (_) {}
  }

  static Future<void> _sendToken(String token) async {
    final url = _gatewayUrl;
    final at = _accessToken;
    if (url == null || at == null) return;
    try {
      final dio = Dio(BaseOptions(
        baseUrl: url,
        connectTimeout: AppConstants.httpTimeout,
        receiveTimeout: AppConstants.httpTimeout,
        headers: {'Authorization': 'Bearer $at', 'Content-Type': 'application/json'},
      ));
      await dio.post('/push/register', data: {'token': token, 'platform': _platform()});
      dio.close();
    } catch (_) {}
  }

  /// Best-effort unregister on logout, then forget the session.
  static Future<void> unregister() async {
    final url = _gatewayUrl;
    final at = _accessToken;
    if (_enabled && url != null && at != null) {
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          final dio = Dio(BaseOptions(
            baseUrl: url,
            connectTimeout: AppConstants.httpTimeout,
            receiveTimeout: AppConstants.httpTimeout,
            headers: {'Authorization': 'Bearer $at', 'Content-Type': 'application/json'},
          ));
          await dio.post('/push/unregister', data: {'token': token});
          dio.close();
        }
      } catch (_) {}
    }
    _gatewayUrl = null;
    _accessToken = null;
  }

  static String _platform() =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
}
