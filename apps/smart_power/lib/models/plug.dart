import 'package:flutter/material.dart';

/// State of a SonOFF plug, derived from a `switch.*` entity + matching sensors.
enum PlugState { on, off, unavailable }

/// Appliance type — drives the dashboard glyph and naming. The list is
/// intentionally open-ended so new appliances can be added without a code
/// change (see "Other"). Per the operator's design intent: "allow the user
/// to add new devices direct from system/dashboard."
///
/// Icons are NOT defined here — widgets must resolve the visual glyph via
/// `lib/config/app_icons.dart` (HugeIcons only). Strict rule from the design
/// docs (`implementation_plan/mobile_design_docs/icons.jsx`).
enum ApplianceType {
  radio,
  fridge,
  heater,
  airConditioner,
  washer,
  waterHeater,
  light,
  other,
}

extension ApplianceTypeLabel on ApplianceType {
  String get label {
    switch (this) {
      case ApplianceType.radio:
        return 'Radio';
      case ApplianceType.fridge:
        return 'Fridge';
      case ApplianceType.heater:
        return 'Heater';
      case ApplianceType.airConditioner:
        return 'Air Conditioner';
      case ApplianceType.washer:
        return 'Washing Machine';
      case ApplianceType.waterHeater:
        return 'Water Heater';
      case ApplianceType.light:
        return 'Light';
      case ApplianceType.other:
        return 'Device';
    }
  }

  /// Critical loads must NEVER be auto-toggled off by idle automations.
  /// Operator requirement (chat log, 2026-05-20).
  bool get isCriticalLoad =>
      this == ApplianceType.fridge || this == ApplianceType.waterHeater;
}

/// View-model object for one plug. Combines the `switch.*` state with its
/// `sensor.*_{power,voltage,current,energy}` readings.
@immutable
class Plug {
  /// Short id used in entity ids — e.g. `radio` for `switch.radio`.
  final String id;
  final String entityId;
  final String name;
  final ApplianceType type;
  final PlugState state;
  final double? powerW;
  final double? voltageV;
  final double? currentA;
  final double? energyTodayKwh;
  final DateTime? lastUpdated;
  final List<double> history; // last N power readings, for sparkline

  const Plug({
    required this.id,
    required this.entityId,
    required this.name,
    required this.type,
    required this.state,
    this.powerW,
    this.voltageV,
    this.currentA,
    this.energyTodayKwh,
    this.lastUpdated,
    this.history = const [],
  });

  bool get isOn => state == PlugState.on;
  bool get isUnavailable => state == PlugState.unavailable;

  Plug copyWith({
    String? name,
    ApplianceType? type,
    PlugState? state,
    double? powerW,
    double? voltageV,
    double? currentA,
    double? energyTodayKwh,
    DateTime? lastUpdated,
    List<double>? history,
  }) {
    return Plug(
      id: id,
      entityId: entityId,
      name: name ?? this.name,
      type: type ?? this.type,
      state: state ?? this.state,
      powerW: powerW ?? this.powerW,
      voltageV: voltageV ?? this.voltageV,
      currentA: currentA ?? this.currentA,
      energyTodayKwh: energyTodayKwh ?? this.energyTodayKwh,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      history: history ?? this.history,
    );
  }

  /// Infer appliance type from the entity name. Falls back to `.other`.
  static ApplianceType inferType(String entityId, String friendlyName) {
    final n = '${entityId.toLowerCase()} ${friendlyName.toLowerCase()}';
    if (n.contains('radio')) return ApplianceType.radio;
    if (n.contains('fridge') || n.contains('refrig')) {
      return ApplianceType.fridge;
    }
    if (n.contains('heater') && n.contains('water')) {
      return ApplianceType.waterHeater;
    }
    if (n.contains('heater')) return ApplianceType.heater;
    if (n.contains('air') || n.contains('ac') || n.contains('aircon')) {
      return ApplianceType.airConditioner;
    }
    if (n.contains('wash') || n.contains('laundry')) return ApplianceType.washer;
    if (n.contains('light') || n.contains('lamp')) return ApplianceType.light;
    return ApplianceType.other;
  }
}

/// Top-level app settings persisted via secure storage.
@immutable
class AppSettings {
  final String? haUrl;
  final String? haToken;
  final ThemeMode themeMode;
  final int pollSeconds;

  const AppSettings({
    this.haUrl,
    this.haToken,
    this.themeMode = ThemeMode.system,
    this.pollSeconds = 10,
  });

  bool get isConfigured =>
      (haUrl?.isNotEmpty ?? false) && (haToken?.isNotEmpty ?? false);

  AppSettings copyWith({
    String? haUrl,
    String? haToken,
    ThemeMode? themeMode,
    int? pollSeconds,
    bool clear = false,
  }) {
    if (clear) {
      return AppSettings(
        themeMode: themeMode ?? this.themeMode,
        pollSeconds: pollSeconds ?? this.pollSeconds,
      );
    }
    return AppSettings(
      haUrl: haUrl ?? this.haUrl,
      haToken: haToken ?? this.haToken,
      themeMode: themeMode ?? this.themeMode,
      pollSeconds: pollSeconds ?? this.pollSeconds,
    );
  }
}
