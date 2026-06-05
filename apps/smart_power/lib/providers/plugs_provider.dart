import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/demo_data.dart';
import '../models/ha_state.dart';
import '../models/plug.dart';
import '../services/ha_api.dart';
import 'settings_provider.dart';

/// Where the plug list currently comes from. Lets the UI tell the difference
/// between "real data" and the demo fallback instead of silently faking plugs.
enum PlugsSource {
  /// Live entities assembled from Plug Assistance.
  live,

  /// Not configured yet — Setup not completed.
  demoUnconfigured,

  /// Configured but the HA client couldn't be built / reached.
  demoNoBackend,

  /// Connected to HA, but no plug-like `switch.*` + sensor pairs were found.
  demoEmpty,
}

extension PlugsSourceX on PlugsSource {
  bool get isDemo => this != PlugsSource.live;
}

/// Current data source for [plugsProvider]. Updated from `_fetchAll`.
final plugsSourceProvider =
    StateProvider<PlugsSource>((_) => PlugsSource.demoUnconfigured);

/// Constructs an [HaApi] from current settings. Null when settings are
/// incomplete — callers should gate on this.
final haApiProvider = Provider<HaApi?>((ref) {
  final settings = ref.watch(settingsProvider).valueOrNull;
  if (settings == null || !settings.isConfigured) return null;
  final api = HaApi(
    baseUrl: settings.gatewayUrl!,
    token: settings.accessToken!,
    // On a 401 the gateway token has expired — renew it via the refresh token.
    refresher: () => ref.read(settingsProvider.notifier).refreshAccessToken(),
  );
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
      _setSource(PlugsSource.demoUnconfigured);
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

  /// Updates [plugsSourceProvider] without tripping Riverpod's
  /// "modified during build" guard — defers when called synchronously.
  void _setSource(PlugsSource source) {
    final controller = ref.read(plugsSourceProvider.notifier);
    if (controller.state != source) {
      Future.microtask(() {
        if (controller.mounted) controller.state = source;
      });
    }
  }

  Future<List<Plug>> _fetchAll() async {
    final api = ref.read(haApiProvider);
    // No live backend → keep the dashboard populated with demo plugs.
    if (api == null) {
      _setSource(PlugsSource.demoNoBackend);
      return DemoData.plugs();
    }
    final all = await api.listStates();
    final assembled = _assemble(all);
    // Connected, but HA exposes no plug-like switches yet. Keep the design
    // populated with demo plugs but flag the source so the UI can warn the
    // operator their entities weren't matched (instead of faking success).
    if (assembled.isEmpty) {
      _setSource(PlugsSource.demoEmpty);
      return DemoData.plugs();
    }
    _setSource(PlugsSource.live);
    return assembled;
  }

  /// Instance wrapper that threads the previously-known plug list in so power
  /// history is preserved across polls.
  List<Plug> _assemble(List<HaStateResponse> states) =>
      assemblePlugs(states, prior: state.valueOrNull ?? const []);

  /// Walks the full state list and groups switch.* entities with their
  /// matching sensor.* readings. Pure function — testable in isolation.
  ///
  /// Sensor matching is SonoffLAN-aware: it tolerates the integration's
  /// `sonoff_` entity-id prefix and matches by suffix alias OR HA
  /// `device_class`, so real device-id entities (e.g.
  /// `switch.sonoff_10024a097a` + `sensor.sonoff_10024a097a_power`) resolve
  /// without hardcoding names. [prior] carries forward per-plug power history.
  static List<Plug> assemblePlugs(
    List<HaStateResponse> states, {
    List<Plug> prior = const [],
  }) {
    final switches =
        states.where((s) => s.entityId.startsWith('switch.')).toList();

    final result = <Plug>[];
    for (final sw in switches) {
      final id = sw.entityId.substring('switch.'.length);
      if (id.isEmpty) continue;

      final sensors = _deviceSensors(states, id);

      // Filter to plug-like switches: must carry at least one telemetry
      // sensor. Skips unrelated switches (automation toggles, groups).
      final powerS = _pick(sensors, const ['power'], const ['power']);
      final voltageS = _pick(sensors, const ['voltage'], const ['voltage']);
      final currentS = _pick(sensors, const ['current'], const ['current']);
      final energyTodayS = _pick(
        sensors,
        const ['energy_today', 'today_energy', 'energy_day', 'day_energy',
            'energy_daily', 'daily_energy', 'energy'],
        const [],
      );
      final energyMonthS = _pick(
        sensors,
        const ['energy_month', 'month_energy', 'energy_monthly',
            'monthly_energy', 'energy_this_month', 'this_month_energy'],
        const [],
      );
      final energyTotalS = _pick(
        sensors,
        const ['energy_total', 'total_energy', 'energy_lifetime',
            'lifetime_energy'],
        const [],
      );
      final rssiS = _pick(
        sensors,
        const ['rssi', 'signal_strength', 'wifi_signal', 'signal'],
        const ['signal_strength'],
      );

      final power = powerS?.asDouble();
      final hasReadings = powerS != null ||
          voltageS != null ||
          currentS != null ||
          energyTodayS != null ||
          energyMonthS != null ||
          energyTotalS != null;
      if (!hasReadings) continue;

      final friendlyName = sw.attributes['friendly_name'] as String? ?? id;
      final type = Plug.inferType(sw.entityId, friendlyName);

      final priorPlug = prior.cast<Plug?>().firstWhere(
            (p) => p?.id == id,
            orElse: () => null,
          );
      final List<double> priorHistory = priorPlug?.history ?? const <double>[];

      final List<double> updatedHistory = power == null
          ? priorHistory
          : (<double>[...priorHistory, power]).takeLast(60);

      // Raw snapshot of every matched sensor for the diagnostics table.
      final readings = <String, PlugReading>{
        for (final s in sensors) s.entityId: _reading(s),
      };

      result.add(Plug(
        id: id,
        entityId: sw.entityId,
        name: friendlyName,
        type: type,
        state: _parseSwitchState(sw.state),
        powerW: power,
        voltageV: voltageS?.asDouble(),
        currentA: currentS?.asDouble(),
        energyTodayKwh: energyTodayS?.asDouble(),
        energyMonthKwh: energyMonthS?.asDouble(),
        energyTotalKwh: energyTotalS?.asDouble(),
        wifiRssiDbm: rssiS?.asDouble(),
        lastUpdated: sw.lastUpdated,
        lastChanged: sw.lastChanged,
        history: updatedHistory,
        attributes: sw.attributes,
        readings: readings,
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

  static final RegExp _sonoffId = RegExp(r'sonoff_([0-9a-z]+)');
  static final RegExp _trailingChannel = RegExp(r'_\d+$');

  /// All `sensor.*` entities belonging to the switch [switchLocal] (the part
  /// after `switch.`).
  ///
  /// SonoffLAN names the controllable switch and its metering sensors with a
  /// shared `sonoff_<deviceid>` segment, but appends a channel index to the
  /// switch (`..._1`) that the sensors lack — e.g.
  /// `switch.s60tpg_sonoff_10024a0989_1` pairs with
  /// `sensor.s60tpg_sonoff_10024a0989_power`. We therefore key off the stable
  /// `sonoff_<deviceid>` token when present, and otherwise fall back to a
  /// channel-stripped stem prefix for non-Sonoff naming.
  static List<HaStateResponse> _deviceSensors(
    List<HaStateResponse> states,
    String switchLocal,
  ) {
    final sw = switchLocal.toLowerCase();
    final idMatch = _sonoffId.firstMatch(sw);
    final stem = sw.replaceFirst(_trailingChannel, '');

    bool belongs(String sensorLocal) {
      // Strong match: the same sonoff device id appears in the sensor id.
      if (idMatch != null) {
        return sensorLocal.contains('sonoff_${idMatch.group(1)}');
      }
      // Generic fallback: channel-stripped stem prefix.
      if (stem.isEmpty) return false;
      return sensorLocal == stem || sensorLocal.startsWith('${stem}_');
    }

    return states.where((s) {
      if (!s.entityId.startsWith('sensor.')) return false;
      return belongs(s.entityId.substring('sensor.'.length).toLowerCase());
    }).toList();
  }

  /// Picks the first numeric sensor in [sensors] matching any [suffixes]
  /// (entity-id `_suffix`) or, failing that, any HA [deviceClasses].
  static HaStateResponse? _pick(
    List<HaStateResponse> sensors,
    List<String> suffixes,
    List<String> deviceClasses,
  ) {
    for (final suffix in suffixes) {
      for (final s in sensors) {
        if (s.entityId.toLowerCase().endsWith('_$suffix') &&
            s.asDouble() != null) {
          return s;
        }
      }
    }
    for (final dc in deviceClasses) {
      for (final s in sensors) {
        final cls = (s.attributes['device_class'] as String?)?.toLowerCase();
        if (cls == dc && s.asDouble() != null) return s;
      }
    }
    return null;
  }

  static PlugReading _reading(HaStateResponse s) => PlugReading(
        entityId: s.entityId,
        state: s.state,
        friendlyName: s.attributes['friendly_name'] as String?,
        unit: s.attributes['unit_of_measurement'] as String?,
        attributes: s.attributes,
      );

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

  /// Optimistic toggle per Handoff §6. Updates UI immediately, sends the
  /// command to Plug Assistance, then reconciles against the device's real
  /// state. Reverts on failure; the caller surfaces a snackbar.
  ///
  /// Returns true when the `turn_on`/`turn_off` service call succeeded —
  /// independent of whether the follow-up reconcile read succeeds.
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
      // HA awaits the integration before the service call returns, so the
      // next /api/states reflects the new on/off state and real power draw.
      // Converge immediately instead of waiting up to a full poll interval.
      // A reconcile failure must NOT flip the success result or clobber the
      // optimistic UI with an error.
      try {
        final fresh = await _fetchAll();
        state = AsyncData(fresh);
      } catch (_) {
        /* keep optimistic state; the next poll will reconcile */
      }
      return true;
    } catch (_) {
      // Command failed → revert and reconcile to the true state.
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
