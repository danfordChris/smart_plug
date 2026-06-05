import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:smart_power/models/plug.dart';
import 'package:smart_power/providers/plugs_provider.dart';
import 'package:smart_power/providers/settings_provider.dart';
import 'package:smart_power/screens/dashboard_screen.dart';

/// Smoke test that the dashboard renders fully with demo data — verifies the
/// hero, plug cards, quick access, and insights are all present.
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('Dashboard shows demo plugs + hero + insights', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Force demo data regardless of stored credentials.
          plugsProvider.overrideWith(_DemoPlugsNotifier.new),
          settingsProvider.overrideWith(_DemoSettingsNotifier.new),
        ],
        child: MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            colorScheme:
                ColorScheme.fromSeed(seedColor: const Color(0xFF1F8A5B)),
          ),
          home: const DashboardScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    // Greeting + subtitle
    expect(find.textContaining('energy overview'), findsOneWidget);
    // Hero labels
    expect(find.text("Today's energy"), findsOneWidget);
    expect(find.text('Estimated cost'), findsOneWidget);
    // Quick access
    expect(find.text('Quick access'), findsOneWidget);
    expect(find.text('Appliances'), findsWidgets);
    // Plug cards (demo)
    expect(find.text('Radio'), findsOneWidget);
    expect(find.text('Fridge'), findsOneWidget);

    // Insights live below the fold — scroll the dashboard list to them.
    await tester.scrollUntilVisible(
      find.text('Insights & alerts'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('Insights & alerts'), findsOneWidget);
    expect(find.text('Standby draw detected'), findsOneWidget);
  });
}

class _DemoPlugsNotifier extends PlugsNotifier {
  @override
  Future<List<Plug>> build() async => _demoPlugs();
}

List<Plug> _demoPlugs() => [
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
        lastUpdated: DateTime.now(),
        history: List<double>.generate(60, (i) => 8 + (i % 5)),
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
        lastUpdated: DateTime.now(),
        history: List<double>.generate(60, (i) => 100 + (i % 30)),
      ),
    ];

class _DemoSettingsNotifier extends SettingsNotifier {
  @override
  Future<AppSettings> build() async => const AppSettings(
        gatewayUrl: 'http://100.83.45.15:8099',
        accessToken: 'demo-access',
      );
}
