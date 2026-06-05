import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:smart_power/models/plug.dart';
import 'package:smart_power/providers/plugs_provider.dart';
import 'package:smart_power/screens/detail_screen.dart';

/// Verifies the expanded Detail screen renders the full telemetry set:
/// the core stat grid, WiFi / month / total tiles, the availability +
/// last-seen row, and the raw-attribute diagnostics section.
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('Detail shows all telemetry + diagnostics', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          plugsProvider.overrideWith(_OneFullPlugNotifier.new),
        ],
        child: MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            colorScheme:
                ColorScheme.fromSeed(seedColor: const Color(0xFF1F8A5B)),
          ),
          home: const DetailScreen(plugId: 'heater'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    // Core 4 + extended tiles (StatTile renders labels uppercased).
    expect(find.text('POWER'), findsOneWidget);
    expect(find.text('VOLTAGE'), findsOneWidget);
    expect(find.text('CURRENT'), findsOneWidget);
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('THIS MONTH'), findsOneWidget);
    expect(find.text('TOTAL'), findsOneWidget);
    expect(find.text('WIFI'), findsOneWidget);

    // Availability strip.
    expect(find.text('Online'), findsOneWidget);

    // Diagnostics section header (raw HA data) is present.
    expect(find.text('Diagnostics'), findsOneWidget);
    expect(find.textContaining('raw Plug Assistance data'), findsOneWidget);
  });
}

class _OneFullPlugNotifier extends PlugsNotifier {
  @override
  Future<List<Plug>> build() async => [
        Plug(
          id: 'heater',
          entityId: 'switch.sonoff_10024a097a',
          name: 'Living Room Heater',
          type: ApplianceType.heater,
          state: PlugState.on,
          powerW: 1047,
          voltageV: 223.4,
          currentA: 4.69,
          energyTodayKwh: 2.31,
          energyMonthKwh: 41.2,
          energyTotalKwh: 612.9,
          wifiRssiDbm: -42,
          lastUpdated: DateTime.now(),
          lastChanged: DateTime.now().subtract(const Duration(minutes: 8)),
          history: List<double>.generate(60, (i) => 1000 + (i % 50).toDouble()),
          attributes: const {'friendly_name': 'Living Room Heater'},
          readings: const {
            'sensor.sonoff_10024a097a_power': PlugReading(
              entityId: 'sensor.sonoff_10024a097a_power',
              state: '1047',
              unit: 'W',
              attributes: {'device_class': 'power'},
            ),
          },
        ),
      ];
}
