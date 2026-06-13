import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device_config.dart';
import '../services/device_config_api.dart';
import 'settings_provider.dart';

/// Builds a [DeviceConfigApi] from the current session. Null until authed.
final deviceConfigApiProvider = Provider<DeviceConfigApi?>((ref) {
  final settings = ref.watch(settingsProvider).valueOrNull;
  if (settings == null || !settings.isConfigured) return null;
  final api = DeviceConfigApi(
    baseUrl: settings.gatewayUrl!,
    token: settings.accessToken!,
    refresher: () => ref.read(settingsProvider.notifier).refreshAccessToken(),
  );
  ref.onDispose(api.dispose);
  return api;
});

/// All of the current user's device configs (used to apply name/type overrides
/// on the dashboard and to drive the config screen).
final deviceConfigsProvider = FutureProvider<List<DeviceConfig>>((ref) async {
  final api = ref.watch(deviceConfigApiProvider);
  if (api == null) return const [];
  return api.list();
});

/// One plug's config. Auto-disposes with the config screen.
final deviceConfigForEntityProvider =
    FutureProvider.autoDispose.family<DeviceConfig, String>((ref, entityId) async {
  final api = ref.watch(deviceConfigApiProvider);
  if (api == null) return DeviceConfig(entityId: entityId);
  return api.get(entityId);
});
