import 'package:flutter_test/flutter_test.dart';

import 'package:smart_power/models/ha_state.dart';
import 'package:smart_power/models/plug.dart';
import 'package:smart_power/providers/plugs_provider.dart';

/// Builds a minimal HA state response for tests.
HaStateResponse st(
  String entityId,
  String state, {
  Map<String, dynamic> attributes = const {},
}) =>
    HaStateResponse(
      entityId: entityId,
      state: state,
      attributes: attributes,
    );

void main() {
  group('assemblePlugs — SonoffLAN naming', () {
    // Exact entity ids from the operator's live Plug Assistance (S60TPG via
    // SonoffLAN). The switch carries a `_1` channel index the sensors lack.
    test('matches real S60TPG entities despite the switch channel suffix', () {
      final states = <HaStateResponse>[
        st('switch.number_01_sonoff_10024a097a_1', 'on',
            attributes: {'friendly_name': 'NUMBER_01'}),
        st('sensor.number_01_sonoff_10024a097a_power', '12.4',
            attributes: {'unit_of_measurement': 'W', 'device_class': 'power'}),
        st('sensor.number_01_sonoff_10024a097a_voltage', '231.0',
            attributes: {
              'unit_of_measurement': 'V',
              'device_class': 'voltage'
            }),
        st('sensor.number_01_sonoff_10024a097a_current', '0.05',
            attributes: {
              'unit_of_measurement': 'A',
              'device_class': 'current'
            }),
        st('sensor.number_01_sonoff_10024a097a_energy_day', '0.11',
            attributes: {
              'unit_of_measurement': 'kWh',
              'device_class': 'energy'
            }),
        st('sensor.number_01_sonoff_10024a097a_energy_month', '0.2',
            attributes: {
              'unit_of_measurement': 'kWh',
              'device_class': 'energy'
            }),
      ];

      final plugs = PlugsNotifier.assemblePlugs(states);

      expect(plugs, hasLength(1));
      final p = plugs.single;
      expect(p.entityId, 'switch.number_01_sonoff_10024a097a_1');
      expect(p.state, PlugState.on);
      expect(p.powerW, 12.4);
      expect(p.voltageV, 231.0);
      expect(p.currentA, 0.05);
      expect(p.energyTodayKwh, 0.11); // from *_energy_day
      expect(p.energyMonthKwh, 0.2); // from *_energy_month
      expect(p.energyTotalKwh, isNull); // no lifetime sensor exists
      // Diagnostics: every matched sensor captured raw.
      expect(p.readings, hasLength(5));
    });

    test('two SonoffLAN devices resolve independently (no cross-match)', () {
      // Both real devices present together — sensors must not bleed across.
      final states = <HaStateResponse>[
        st('switch.number_01_sonoff_10024a097a_1', 'on',
            attributes: {'friendly_name': 'NUMBER_01'}),
        st('sensor.number_01_sonoff_10024a097a_power', '12.4',
            attributes: {'unit_of_measurement': 'W'}),
        st('switch.s60tpg_sonoff_10024a0989_1', 'on',
            attributes: {'friendly_name': 'S60TPG'}),
        st('sensor.s60tpg_sonoff_10024a0989_power', '880.0',
            attributes: {'unit_of_measurement': 'W'}),
        st('sensor.s60tpg_sonoff_10024a0989_energy_day', '0.0',
            attributes: {'unit_of_measurement': 'kWh'}),
      ];

      final plugs = PlugsNotifier.assemblePlugs(states);
      expect(plugs, hasLength(2));
      final byId = {for (final p in plugs) p.entityId: p};
      expect(byId['switch.number_01_sonoff_10024a097a_1']!.powerW, 12.4);
      expect(byId['switch.number_01_sonoff_10024a097a_1']!.readings,
          hasLength(1));
      expect(byId['switch.s60tpg_sonoff_10024a0989_1']!.powerW, 880.0);
      expect(
          byId['switch.s60tpg_sonoff_10024a0989_1']!.readings, hasLength(2));
    });

    test('matches by device_class when entity-id suffix is unusual', () {
      final states = <HaStateResponse>[
        st('switch.fridge', 'on', attributes: {'friendly_name': 'Fridge'}),
        // No "_power" suffix — only the device_class identifies it.
        st('sensor.fridge_active_w', '124.6',
            attributes: {'unit_of_measurement': 'W', 'device_class': 'power'}),
      ];

      final plugs = PlugsNotifier.assemblePlugs(states);
      expect(plugs, hasLength(1));
      expect(plugs.single.powerW, 124.6);
    });

    test('separates energy today / month / total counters', () {
      final states = <HaStateResponse>[
        st('switch.radio', 'on', attributes: {'friendly_name': 'Radio'}),
        st('sensor.radio_power', '8.0',
            attributes: {'unit_of_measurement': 'W'}),
        st('sensor.radio_energy_today', '0.18',
            attributes: {'unit_of_measurement': 'kWh'}),
        st('sensor.radio_energy_month', '4.7',
            attributes: {'unit_of_measurement': 'kWh'}),
        st('sensor.radio_energy_total', '63.4',
            attributes: {'unit_of_measurement': 'kWh'}),
      ];

      final plugs = PlugsNotifier.assemblePlugs(states);
      final p = plugs.single;
      expect(p.energyTodayKwh, 0.18);
      expect(p.energyMonthKwh, 4.7);
      expect(p.energyTotalKwh, 63.4);
    });

    test('skips switches with no telemetry sensors', () {
      final states = <HaStateResponse>[
        st('switch.kitchen_scene', 'on'),
        st('switch.all_lights', 'off'),
      ];
      expect(PlugsNotifier.assemblePlugs(states), isEmpty);
    });

    test('unavailable switch still surfaces if it has sensors', () {
      final states = <HaStateResponse>[
        st('switch.fridge', 'unavailable',
            attributes: {'friendly_name': 'Fridge'}),
        st('sensor.fridge_power', 'unavailable',
            attributes: {'unit_of_measurement': 'W'}),
        st('sensor.fridge_voltage', '230',
            attributes: {'unit_of_measurement': 'V'}),
      ];
      final plugs = PlugsNotifier.assemblePlugs(states);
      expect(plugs, hasLength(1));
      expect(plugs.single.isUnavailable, isTrue);
      expect(plugs.single.powerW, isNull); // unparseable → null
      expect(plugs.single.voltageV, 230);
    });

    test('carries power history forward across polls', () {
      final prior = [
        const Plug(
          id: 'radio',
          entityId: 'switch.radio',
          name: 'Radio',
          type: ApplianceType.radio,
          state: PlugState.on,
          history: [5, 6, 7],
        ),
      ];
      final states = <HaStateResponse>[
        st('switch.radio', 'on', attributes: {'friendly_name': 'Radio'}),
        st('sensor.radio_power', '8.0',
            attributes: {'unit_of_measurement': 'W'}),
      ];
      final plugs = PlugsNotifier.assemblePlugs(states, prior: prior);
      expect(plugs.single.history, [5, 6, 7, 8.0]);
    });

    test('critical loads sort last', () {
      final states = <HaStateResponse>[
        st('switch.fridge', 'on', attributes: {'friendly_name': 'Fridge'}),
        st('sensor.fridge_power', '120',
            attributes: {'unit_of_measurement': 'W'}),
        st('switch.radio', 'on', attributes: {'friendly_name': 'Radio'}),
        st('sensor.radio_power', '8',
            attributes: {'unit_of_measurement': 'W'}),
      ];
      final plugs = PlugsNotifier.assemblePlugs(states);
      expect(plugs.map((p) => p.type).toList(),
          [ApplianceType.radio, ApplianceType.fridge]);
    });
  });
}
