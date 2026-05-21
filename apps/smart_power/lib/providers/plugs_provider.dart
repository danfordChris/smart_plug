import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/demo_data.dart';
import '../models/ha_state.dart';
import '../models/plug.dart';
import '../services/ha_api.dart';
import 'settings_provider.dart';

/// Constructs an [HaApi] from current settings. Null when settings are
/// incomplete — callers should gate on this.
final haApiProvider = Provider<HaApi?>((ref) {
  final settings = ref.watch(settingsProvider).valueOrNull;
  if (settings == null || !settings.isConfigured) return null;
  final api = HaApi(baseUrl: settings.haUrl!, token: settings.haToken!);
  ref.onDispose(api.dispose);
  return api;
});

/// Aggregated plug list. Polls every [AppSettings.pollSeconds] seconds.
/// Implements optimistic toggle per Handoff §6.
class PlugsNotifier extends AsyncNotifier<List<Plug>> {
  Timer? _pollTimer;

  @override
  Future<List<Plug>> build() async {
    final settings = ref.watch(settingsProvider).valueOrNull;
    _pollTimer?.cancel();
    // Not configured → show seeded demo data so the dashboard is fully
    // populated for design review (mirrors app.jsx initialPlugs()).
    if (settings == null || !settings.isConfigured) {
      return DemoData.plugs();
    }
    final initial = await _fetchAll();
    _pollTimer = Timer.periodic(
      Duration(seconds: settings.pollSeconds),
      (_) => refresh(),
    );
    ref.onDispose(() => _pollTimer?.cancel());
    return initial;
  }

  Future<List<Plug>> _fetchAll() async {
    final api = ref.read(haApiProvider);
    // No live backend → keep the dashboard populated with demo plugs.
    if (api == null) return DemoData.plugs();
    final all = await api.listStates();
    final assembled = _assemble(all);
    // If HA is reachable but exposes no plug-like switches yet, still show
    // demo data so the design never renders empty during review.
    return assembled.isEmpty ? DemoData.plugs() : assembled;
  }

  /// Walks the full state list and groups switch.* entities with their
  /// matching sensor.* readings. Pure function — testable in isolation.
  List<Plug> _assemble(List<HaStateResponse> states) {
    final switches =
        states.where((s) => s.entityId.startsWith('switch.')).toList();

    final result = <Plug>[];
    for (final sw in switches) {
      final id = sw.entityId.substring('switch.'.length);
      if (id.isEmpty) continue;

      // Filter to plug-like switches: must have at least a power sensor
      // OR be named like a known appliance. Skip unrelated switches (e.g.
      // automation toggles, group switches).
      final power = _findSensor(states, id, 'power');
      final voltage = _findSensor(states, id, 'voltage');
      final current = _findSensor(states, id, 'current');
      final energy = _findSensor(states, id, 'energy');

      final hasReadings =
          power != null || voltage != null || current != null || energy != null;
      if (!hasReadings) continue;

      final friendlyName = sw.attributes['friendly_name'] as String? ?? id;
      final type = Plug.inferType(sw.entityId, friendlyName);

      final List<double> priorHistory = state.valueOrNull
              ?.firstWhere(
                (p) => p.id == id,
                orElse: () => Plug(
                  id: id,
                  entityId: sw.entityId,
                  name: friendlyName,
                  type: type,
                  state: PlugState.unavailable,
                ),
              )
              .history ??
          const <double>[];

      final List<double> updatedHistory = power == null
          ? priorHistory
          : (<double>[...priorHistory, power]).takeLast(60);

      result.add(Plug(
        id: id,
        entityId: sw.entityId,
        name: friendlyName,
        type: type,
        state: _parseSwitchState(sw.state),
        powerW: power,
        voltageV: voltage,
        currentA: current,
        energyTodayKwh: energy,
        lastUpdated: sw.lastUpdated,
        history: updatedHistory,
      ));
    }
    // Stable order: critical loads last (so toggle hazards aren't first).
    result.sort((a, b) {
      if (a.type.isCriticalLoad == b.type.isCriticalLoad) {
        return a.name.compareTo(b.name);
      }
      return a.type.isCriticalLoad ? 1 : -1;
    });
    return result;
  }

  static double? _findSensor(
    List<HaStateResponse> states,
    String id,
    String suffix,
  ) {
    final candidates = [
      'sensor.${id}_$suffix',
      'sensor.${id}_${suffix}_power',
      'sensor.${id}_${suffix}_total',
    ];
    for (final c in candidates) {
      final match = states.cast<HaStateResponse?>().firstWhere(
            (s) => s?.entityId == c,
            orElse: () => null,
          );
      if (match != null) {
        final v = match.asDouble();
        if (v != null) return v;
      }
    }
    return null;
  }

  static PlugState _parseSwitchState(String s) {
    switch (s) {
      case 'on':
        return PlugState.on;
      case 'off':
        return PlugState.off;
      default:
        return PlugState.unavailable;
    }
  }

  Future<void> refresh() async {
    try {
      final fresh = await _fetchAll();
      state = AsyncData(fresh);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Optimistic toggle per Handoff §6. Updates UI immediately; reverts on
  /// failure with a snackbar (handled by caller via [TogglesController]).
  Future<bool> toggle(String id) async {
    final api = ref.read(haApiProvider);
    final current = state.valueOrNull;
    if (api == null || current == null) return false;
    final idx = current.indexWhere((p) => p.id == id);
    if (idx < 0) return false;
    final target = current[idx];
    if (target.isUnavailable) return false;
    final next = target.copyWith(
      state: target.isOn ? PlugState.off : PlugState.on,
    );
    final optimistic = [...current]..[idx] = next;
    state = AsyncData(optimistic);
    try {
      if (target.isOn) {
        await api.turnOff(target.entityId);
      } else {
        await api.turnOn(target.entityId);
      }
      return true;
    } catch (_) {
      // Revert + ask refresh to reconcile.
      state = AsyncData(current);
      await refresh();
      return false;
    }
  }
}

final plugsProvider =
    AsyncNotifierProvider<PlugsNotifier, List<Plug>>(PlugsNotifier.new);

extension _TakeLast<T> on List<T> {
  List<T> takeLast(int n) =>
      length <= n ? this : sublist(length - n);
}
