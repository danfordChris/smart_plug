import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_power/models/ha_state.dart';
import 'package:smart_power/models/plug.dart';
import 'package:smart_power/services/ha_api.dart';
import 'package:smart_power/providers/plugs_provider.dart';
import 'package:smart_power/providers/settings_provider.dart';

/// Mutable in-memory stand-in for Plug Assistance. `turn_on`/`turn_off` flip
/// the backing switch state AND its power sensor, so `listStates()` reflects
/// commands — exercising the full out (command) → in (read-back) loop.
class FakeHaApi implements HaApi {
  FakeHaApi({this.failTurnOff = false});

  final bool failTurnOff;
  String switchState = 'on';
  double power = 12.4;

  final List<String> calls = [];

  static const _entity = 'switch.number_01_sonoff_10024a097a_1';

  @override
  Future<List<HaStateResponse>> listStates() async => [
        HaStateResponse(
          entityId: _entity,
          state: switchState,
          attributes: const {'friendly_name': 'NUMBER_01'},
        ),
        HaStateResponse(
          entityId: 'sensor.number_01_sonoff_10024a097a_power',
          state: '$power',
          attributes: const {'unit_of_measurement': 'W'},
        ),
      ];

  @override
  Future<void> turnOn(String entityId) async {
    calls.add('turn_on:$entityId');
    switchState = 'on';
    power = 12.4;
  }

  @override
  Future<void> turnOff(String entityId) async {
    calls.add('turn_off:$entityId');
    if (failTurnOff) throw Exception('network down');
    switchState = 'off';
    power = 0.0;
  }

  // Unused by the control loop under test.
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Builds a container and resolves settings BEFORE plugs, so the first
/// plugsProvider build already sees configured settings (no demo detour) and
/// uses a long poll interval that won't fire during the test.
Future<({ProviderContainer c, List<Plug> plugs})> _ready(FakeHaApi fake) async {
  final c = ProviderContainer(
    overrides: [
      settingsProvider.overrideWith(_ConfiguredSettings.new),
      haApiProvider.overrideWithValue(fake),
    ],
  );
  addTearDown(c.dispose);
  await c.read(settingsProvider.future);
  final plugs = await c.read(plugsProvider.future);
  return (c: c, plugs: plugs);
}

void main() {
  group('control loop — toggle out → state in', () {
    test('turning OFF calls HA with the real entity and converges to off',
        () async {
      final fake = FakeHaApi();
      final (:c, :plugs) = await _ready(fake);

      expect(plugs.single.isOn, isTrue);
      final id = plugs.single.id;

      final ok = await c.read(plugsProvider.notifier).toggle(id);

      expect(ok, isTrue);
      // Correct service + exact real entity id went OUT to HA.
      expect(fake.calls,
          ['turn_off:switch.number_01_sonoff_10024a097a_1']);
      // State read back IN reflects the device: off + power dropped to 0.
      final after = c.read(plugsProvider).requireValue.single;
      expect(after.isOn, isFalse);
      expect(after.powerW, 0.0);
    });

    test('failed command reverts to the prior state and returns false',
        () async {
      final fake = FakeHaApi(failTurnOff: true);
      final (:c, :plugs) = await _ready(fake);

      final id = plugs.single.id;
      expect(plugs.single.isOn, isTrue);

      final ok = await c.read(plugsProvider.notifier).toggle(id);

      expect(ok, isFalse);
      expect(fake.calls,
          ['turn_off:switch.number_01_sonoff_10024a097a_1']);
      // Reverted: still on (the device never actually switched).
      final after = c.read(plugsProvider).requireValue.single;
      expect(after.isOn, isTrue);
    });

    test('toggle is a no-op on an unavailable plug', () async {
      final fake = FakeHaApi()..switchState = 'unavailable';
      final (:c, :plugs) = await _ready(fake);

      expect(plugs.single.isUnavailable, isTrue);

      final ok = await c.read(plugsProvider.notifier).toggle(plugs.single.id);
      expect(ok, isFalse);
      expect(fake.calls, isEmpty); // never reached HA
    });
  });
}

class _ConfiguredSettings extends SettingsNotifier {
  @override
  Future<AppSettings> build() async => const AppSettings(
        gatewayUrl: 'http://100.83.45.15:8099',
        accessToken: 'test-access',
        refreshToken: 'test-refresh',
        role: 'admin',
        pollSeconds: 3600, // don't let the poll timer fire mid-test
      );
}
