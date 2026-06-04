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
/// `sensor.*_{power,voltage,current,energy,...}` readings plus diagnostics
/// (WiFi signal, availability, last-seen) and the raw HA attribute payloads.
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

  /// Energy counters beyond "today". SonoffLAN/HA may expose monthly and
  /// lifetime totals (or these are derived via `utility_meter` helpers).
  final double? energyMonthKwh;
  final double? energyTotalKwh;

  /// WiFi signal strength in dBm (HA `signal_strength` sensor / `rssi`).
  final double? wifiRssiDbm;

  final DateTime? lastUpdated;

  /// When the switch state last *changed* (HA `last_changed`). Distinct from
  /// [lastUpdated], which ticks on any attribute refresh.
  final DateTime? lastChanged;

  final List<double> history; // last N power readings, for sparkline

  /// Raw attribute map of the backing `switch.*` entity — surfaced verbatim
  /// in the Detail screen diagnostics section for full transparency.
  final Map<String, dynamic> attributes;

  /// Raw state + attributes of every sensor matched to this plug, keyed by
  /// entity id (e.g. `sensor.radio_power`). Drives the diagnostics table.
  final Map<String, PlugReading> readings;

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
    this.energyMonthKwh,
    this.energyTotalKwh,
    this.wifiRssiDbm,
    this.lastUpdated,
    this.lastChanged,
    this.history = const [],
    this.attributes = const {},
    this.readings = const {},
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
    double? energyMonthKwh,
    double? energyTotalKwh,
    double? wifiRssiDbm,
    DateTime? lastUpdated,
    DateTime? lastChanged,
    List<double>? history,
    Map<String, dynamic>? attributes,
    Map<String, PlugReading>? readings,
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
      energyMonthKwh: energyMonthKwh ?? this.energyMonthKwh,
      energyTotalKwh: energyTotalKwh ?? this.energyTotalKwh,
      wifiRssiDbm: wifiRssiDbm ?? this.wifiRssiDbm,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      lastChanged: lastChanged ?? this.lastChanged,
      history: history ?? this.history,
      attributes: attributes ?? this.attributes,
      readings: readings ?? this.readings,
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

/// A single raw sensor snapshot matched to a plug — its entity id, current
/// state string, friendly name, unit, and full attribute map. Used by the
/// Detail screen's diagnostics table so every value HA exposes is visible.
@immutable
class PlugReading {
  final String entityId;
  final String state;
  final String? friendlyName;
  final String? unit;
  final Map<String, dynamic> attributes;

  const PlugReading({
    required this.entityId,
    required this.state,
    this.friendlyName,
    this.unit,
    this.attributes = const {},
  });

  /// `"123.4 W"` style label, falling back to the bare state when no unit.
  String get display => unit == null || unit!.isEmpty ? state : '$state $unit';
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
