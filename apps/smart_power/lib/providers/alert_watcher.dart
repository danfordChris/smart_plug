import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/alert.dart';
import '../services/notifications.dart';
import 'alerts_provider.dart';
import 'settings_provider.dart';

/// Polls the gateway alerts feed while signed in and raises a system
/// notification for each newly-arrived alert. Kept alive app-wide by a
/// `ref.watch(alertWatcherProvider)` in the home shell.
///
/// On first run it primes `_lastSeenId` to the newest existing alert so the
/// user isn't spammed with a backlog of historical events.
class AlertWatcher {
  AlertWatcher(this._ref) {
    _start();
  }

  final Ref _ref;
  Timer? _timer;
  int _lastSeenId = -1;
  bool _primed = false;

  void _start() {
    // Cadence mirrors plug polling; alerts are low-volume so this is cheap.
    final seconds = _ref.read(settingsProvider).valueOrNull?.pollSeconds ?? 10;
    _poll();
    _timer = Timer.periodic(
      Duration(seconds: seconds.clamp(10, 60)),
      (_) => _poll(),
    );
  }

  Future<void> _poll() async {
    final api = _ref.read(alertsApiProvider);
    if (api == null) return;
    List<AppAlert> alerts;
    try {
      alerts = await api.list(limit: 20);
    } catch (_) {
      return;
    }
    if (alerts.isEmpty) return;

    final maxId = alerts.map((a) => a.id).reduce((a, b) => a > b ? a : b);
    if (!_primed) {
      _lastSeenId = maxId; // don't notify for pre-existing alerts
      _primed = true;
      return;
    }

    // Newest first → notify ascending so order reads naturally.
    final fresh = alerts.where((a) => a.id > _lastSeenId).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    for (final a in fresh) {
      await LocalNotifications.show(
        id: a.id,
        title: _titleFor(a.kind),
        body: a.message,
      );
    }
    if (maxId > _lastSeenId) _lastSeenId = maxId;
  }

  static String _titleFor(String kind) {
    switch (kind) {
      case 'offline':
        return 'Plug offline';
      case 'online':
        return 'Plug back online';
      case 'auto_off':
        return 'Auto-off';
      case 'schedule_fired':
        return 'Schedule';
      default:
        return 'Smart Power';
    }
  }

  void dispose() => _timer?.cancel();
}

/// Lives as long as something watches it (the home shell). Rebuilds when the
/// session changes so it stops polling on logout and restarts on login.
final alertWatcherProvider = Provider<AlertWatcher?>((ref) {
  final settings = ref.watch(settingsProvider).valueOrNull;
  if (settings == null || !settings.isConfigured) return null;
  final watcher = AlertWatcher(ref);
  ref.onDispose(watcher.dispose);
  return watcher;
});
