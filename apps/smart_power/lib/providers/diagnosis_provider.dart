import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/diagnosis.dart';
import '../models/plug.dart';
import '../services/diagnosis_api.dart';
import 'plugs_provider.dart';
import 'settings_provider.dart';

final diagnosisApiProvider = Provider<DiagnosisApi?>((ref) {
  final settings = ref.watch(settingsProvider).valueOrNull;
  if (settings == null || !settings.isConfigured) return null;
  final api = DiagnosisApi(
    baseUrl: settings.gatewayUrl!,
    token: settings.accessToken!,
    refresher: () => ref.read(settingsProvider.notifier).refreshAccessToken(),
  );
  ref.onDispose(api.dispose);
  return api;
});

/// Diagnosis for one plug. Auto-disposes with the detail screen; null when not
/// signed in (the UI shows nothing rather than demo noise).
final plugDiagnosisProvider =
    FutureProvider.autoDispose.family<Diagnosis?, String>((ref, entityId) async {
  final api = ref.watch(diagnosisApiProvider);
  if (api == null) return null;
  return api.get(entityId);
});

/// Diagnoses across all live plugs that need attention (or carry an actionable
/// notice) — drives the Insights "Recommendations" section. Empty when not
/// signed in, so demo/preview keeps its static tips.
final flaggedDiagnosesProvider =
    FutureProvider.autoDispose<List<Diagnosis>>((ref) async {
  final api = ref.watch(diagnosisApiProvider);
  if (api == null) return const [];
  final plugs = ref.read(plugsProvider).valueOrNull ?? const <Plug>[];
  final out = <Diagnosis>[];
  for (final p in plugs) {
    try {
      final d = await api.get(p.entityId);
      if (!d.isHealthy && !d.isCollecting) out.add(d);
    } catch (_) {
      // skip this plug
    }
  }
  // Worst first.
  const rank = {'critical': 0, 'warning': 1, 'info': 2, 'ok': 3};
  out.sort((a, b) => (rank[a.severity] ?? 3).compareTo(rank[b.severity] ?? 3));
  return out;
});
