import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/schedule.dart';
import '../services/schedule_api.dart';
import 'settings_provider.dart';

/// Builds a [ScheduleApi] from the current session. Null until the user is
/// authenticated against the gateway.
final scheduleApiProvider = Provider<ScheduleApi?>((ref) {
  final settings = ref.watch(settingsProvider).valueOrNull;
  if (settings == null || !settings.isConfigured) return null;
  final api = ScheduleApi(
    baseUrl: settings.gatewayUrl!,
    token: settings.accessToken!,
    refresher: () => ref.read(settingsProvider.notifier).refreshAccessToken(),
  );
  ref.onDispose(api.dispose);
  return api;
});

/// Schedules for a single plug entity. Auto-disposes when the detail screen
/// is closed.
final schedulesForEntityProvider =
    FutureProvider.autoDispose.family<List<Schedule>, String>((ref, entityId) async {
  final api = ref.watch(scheduleApiProvider);
  if (api == null) return const [];
  final all = await api.list();
  return all.where((s) => s.entityId == entityId).toList()
    ..sort((a, b) => a.timeHhmm.compareTo(b.timeHhmm));
});
