import 'dart:math' as math;

import '../models/plug.dart';

/// Seed/demo plug data — mirrors `initialPlugs()` in
/// `implementation_plan/mobile_design_docs/app.jsx` (lines 18-55).
///
/// Used as a fallback so the dashboard renders fully even before a live
/// Home Assistant fetch succeeds (or when the backend is unreachable during
/// design review). Once a real fetch returns plugs, these are replaced.
class DemoData {
  DemoData._();

  /// Radio history — steady ~8 W with two small spikes (JSX radioHist).
  static List<double> _radioHistory() {
    return List<double>.generate(60, (i) {
      final base = 7.8 + math.sin(i * 0.5) * 0.6;
      final spike = (i == 28 || i == 41) ? 3.0 : 0.0;
      return math.max(0, base + spike);
    });
  }

  /// Fridge history — compressor cycles ~every 15 min (JSX fridgeHist).
  static List<double> _fridgeHistory() {
    return List<double>.generate(60, (i) {
      final cycle = math.sin((i / 15) * math.pi);
      final compressor = cycle > 0.3 ? 110 + cycle * 30 : 4 + cycle * 2;
      return math.max(0, compressor);
    });
  }

  static List<Plug> plugs() {
    final now = DateTime.now();
    return [
      Plug(
        id: 'radio',
        entityId: 'switch.radio',
        name: 'Radio',
        type: ApplianceType.radio,
        state: PlugState.on,
        powerW: 8.2,
        voltageV: 229.4,
        currentA: 0.036,
        energyTodayKwh: 0.18,
        lastUpdated: now,
        history: _radioHistory(),
      ),
      Plug(
        id: 'fridge',
        entityId: 'switch.fridge',
        name: 'Fridge',
        type: ApplianceType.fridge,
        state: PlugState.on,
        powerW: 124.6,
        voltageV: 229.1,
        currentA: 0.544,
        energyTodayKwh: 1.42,
        lastUpdated: now,
        history: _fridgeHistory(),
      ),
    ];
  }

  /// "Other appliances" baseline kWh added to the hero total so the card
  /// reads a realistic whole-home figure (~18.7 kWh) like the JSX prototype.
  static const double otherAppliancesKwh = 17.1;
}
