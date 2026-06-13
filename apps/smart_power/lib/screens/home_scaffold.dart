import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../providers/alert_watcher.dart';
import '../widgets/smart_bottom_nav.dart';
import 'dashboard_screen.dart';
import 'detail_screen.dart';
import 'devices_screen.dart';
import 'insights_screen.dart';
import 'settings_screen.dart';

class HomeScaffold extends ConsumerStatefulWidget {
  const HomeScaffold({super.key});

  @override
  ConsumerState<HomeScaffold> createState() => _HomeScaffoldState();
}

class _HomeScaffoldState extends ConsumerState<HomeScaffold> {
  // START_TAB lets screenshot tooling open a specific tab at launch
  // (0=Home, 1=Devices, 3=Insights, 4=Profile). Defaults to Home.
  int _index = const int.fromEnvironment('START_TAB', defaultValue: 0);

  @override
  void initState() {
    super.initState();
    // START_DETAIL=<plugId> auto-opens a plug detail at launch (screenshot aid).
    const detailId = String.fromEnvironment('START_DETAIL');
    if (detailId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => DetailScreen(plugId: detailId)),
          );
        }
      });
    }
  }

  void _select(int i) => setState(() => _index = i);

  void _showAddDevice() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.sheet),
        ),
      ),
      builder: (_) => const _AddDeviceSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Keep the alert watcher alive while the authed shell is mounted: it polls
    // the gateway feed and raises system notifications for new alerts.
    ref.watch(alertWatcherProvider);
    final pages = [
      DashboardScreen(
        onOpenInsights: () => _select(3),
        onOpenDevices: () => _select(1),
        onAddDevice: _showAddDevice,
      ),
      const DevicesScreen(),
      const SizedBox.shrink(),
      const InsightsScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: SmartBottomNav(
        currentIndex: _index,
        onDestinationSelected: _select,
        onAddDevice: _showAddDevice,
      ),
    );
  }
}

class _AddDeviceSheet extends StatelessWidget {
  const _AddDeviceSheet();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          AppSpacing.l,
          AppSpacing.xxl,
          AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            Text(
              'Adding a new plug',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 22,
                  ),
            ),
            const SizedBox(height: AppSpacing.s),
            Text(
              'Pair new SonOFF plugs in the eWeLink app, then add them to '
              'Plug Assistance via the SonOFF LAN integration. They show up '
              'here automatically.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.55,
                  ),
            ),
            const SizedBox(height: AppSpacing.l),
            ..._steps(context, scheme),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.button),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _steps(BuildContext context, ColorScheme scheme) {
    final items = const [
      'Press the plug button for 5 s until it blinks blue.',
      'Pair it in the eWeLink app.',
      'In HA, Settings → Devices → SonOFF → Refresh.',
      'Pull to refresh this screen.',
    ];
    return [
      for (int i = 0; i < items.length; i++) ...[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    items[i],
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface,
                          height: 1.5,
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ];
  }
}
