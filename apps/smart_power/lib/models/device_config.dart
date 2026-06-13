import 'package:flutter/foundation.dart';

import 'plug.dart';

/// Per-user, per-plug configuration from the gateway: display overrides
/// (name/type) plus the idle auto-off policy and the alerts opt-in.
@immutable
class DeviceConfig {
  final String entityId;
  final String displayName; // '' = use HA friendly name
  final String applianceType; // ApplianceType enum name, or '' = infer
  final bool autoOffEnabled;
  final int autoOffIdleMinutes;
  final double autoOffThresholdW;
  final String powerEntityId;
  final bool alertsEnabled;

  const DeviceConfig({
    required this.entityId,
    this.displayName = '',
    this.applianceType = '',
    this.autoOffEnabled = false,
    this.autoOffIdleMinutes = 30,
    this.autoOffThresholdW = 5.0,
    this.powerEntityId = '',
    this.alertsEnabled = true,
  });

  factory DeviceConfig.fromJson(Map<String, dynamic> j) => DeviceConfig(
        entityId: j['entity_id'] as String? ?? '',
        displayName: j['display_name'] as String? ?? '',
        applianceType: j['appliance_type'] as String? ?? '',
        autoOffEnabled: j['auto_off_enabled'] as bool? ?? false,
        autoOffIdleMinutes: (j['auto_off_idle_minutes'] as num?)?.toInt() ?? 30,
        autoOffThresholdW: (j['auto_off_threshold_w'] as num?)?.toDouble() ?? 5.0,
        powerEntityId: j['power_entity_id'] as String? ?? '',
        alertsEnabled: j['alerts_enabled'] as bool? ?? true,
      );

  ApplianceType? get typeOverride => applianceTypeFromName(applianceType);
}

/// Maps a gateway appliance-type enum name back to [ApplianceType].
/// Returns null for '' or anything unrecognised (caller keeps the inferred type).
ApplianceType? applianceTypeFromName(String name) {
  switch (name) {
    case 'radio':
      return ApplianceType.radio;
    case 'fridge':
      return ApplianceType.fridge;
    case 'heater':
      return ApplianceType.heater;
    case 'airConditioner':
      return ApplianceType.airConditioner;
    case 'washer':
      return ApplianceType.washer;
    case 'waterHeater':
      return ApplianceType.waterHeater;
    case 'light':
      return ApplianceType.light;
    case 'other':
      return ApplianceType.other;
    default:
      return null;
  }
}

/// The enum name the gateway expects for an [ApplianceType].
String applianceTypeName(ApplianceType t) => t.name;

/// Applies user overrides (display name / appliance type) on top of the
/// HA-derived plug list. Pure — unit-tested.
List<Plug> applyDeviceOverrides(List<Plug> plugs, List<DeviceConfig> configs) {
  if (configs.isEmpty) return plugs;
  final byEntity = {for (final c in configs) c.entityId: c};
  return [
    for (final p in plugs)
      if (byEntity[p.entityId] case final c?)
        p.copyWith(
          name: c.displayName.isNotEmpty ? c.displayName : null,
          type: c.typeOverride,
        )
      else
        p,
  ];
}
