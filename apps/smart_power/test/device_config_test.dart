import 'package:flutter_test/flutter_test.dart';
import 'package:smart_power/models/device_config.dart';
import 'package:smart_power/models/plug.dart';

Plug _plug(String id, {String name = 'Raw', ApplianceType type = ApplianceType.other}) =>
    Plug(id: id, entityId: 'switch.$id', name: name, type: type, state: PlugState.on);

void main() {
  group('DeviceConfig.fromJson', () {
    test('maps gateway payload', () {
      final c = DeviceConfig.fromJson({
        'entity_id': 'switch.radio',
        'display_name': 'Studio Radio',
        'appliance_type': 'radio',
        'auto_off_enabled': true,
        'auto_off_idle_minutes': 15,
        'auto_off_threshold_w': 7.5,
        'power_entity_id': 'sensor.radio_power',
        'alerts_enabled': false,
      });
      expect(c.displayName, 'Studio Radio');
      expect(c.typeOverride, ApplianceType.radio);
      expect(c.autoOffEnabled, isTrue);
      expect(c.autoOffIdleMinutes, 15);
      expect(c.autoOffThresholdW, 7.5);
      expect(c.alertsEnabled, isFalse);
    });

    test('unknown/empty type → null override', () {
      expect(DeviceConfig.fromJson({'entity_id': 'switch.x'}).typeOverride, isNull);
      expect(DeviceConfig.fromJson({'entity_id': 'switch.x', 'appliance_type': 'toaster'}).typeOverride, isNull);
    });
  });

  group('applyDeviceOverrides', () {
    test('overrides name and type by entity', () {
      final plugs = [_plug('radio'), _plug('fan')];
      final configs = [
        const DeviceConfig(entityId: 'switch.radio', displayName: 'Kitchen Radio', applianceType: 'fridge'),
      ];
      final out = applyDeviceOverrides(plugs, configs);
      expect(out[0].name, 'Kitchen Radio');
      expect(out[0].type, ApplianceType.fridge);
      // Untouched plug stays as-is.
      expect(out[1].name, 'Raw');
      expect(out[1].type, ApplianceType.other);
    });

    test('blank name / unknown type keep original', () {
      final plugs = [_plug('radio', name: 'Original', type: ApplianceType.radio)];
      final configs = [const DeviceConfig(entityId: 'switch.radio')];
      final out = applyDeviceOverrides(plugs, configs);
      expect(out[0].name, 'Original');
      expect(out[0].type, ApplianceType.radio);
    });

    test('empty configs is a no-op', () {
      final plugs = [_plug('radio')];
      expect(applyDeviceOverrides(plugs, const []), same(plugs));
    });
  });
}
