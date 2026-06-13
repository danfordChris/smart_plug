import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/alert.dart';
import '../services/alerts_api.dart';
import 'settings_provider.dart';

final alertsApiProvider = Provider<AlertsApi?>((ref) {
  final settings = ref.watch(settingsProvider).valueOrNull;
  if (settings == null || !settings.isConfigured) return null;
  final api = AlertsApi(
    baseUrl: settings.gatewayUrl!,
    token: settings.accessToken!,
    refresher: () => ref.read(settingsProvider.notifier).refreshAccessToken(),
  );
  ref.onDispose(api.dispose);
  return api;
});

/// The current user's alerts feed (most recent first).
final alertsProvider =
    FutureProvider.autoDispose<List<AppAlert>>((ref) async {
  final api = ref.watch(alertsApiProvider);
  if (api == null) return const [];
  return api.list();
});

/// Unread alert count for a badge.
final unreadAlertsCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final api = ref.watch(alertsApiProvider);
  if (api == null) return 0;
  return api.unreadCount();
});
