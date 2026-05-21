import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../config/app_icons.dart';
import '../config/demo_data.dart';
import '../config/theme.dart';
import '../models/plug.dart';
import '../providers/plugs_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/connection_banner.dart';
import '../widgets/energy_hero_card.dart';
import '../widgets/insight_card.dart';
import '../widgets/plug_card.dart';
import '../widgets/quick_access_tile.dart';
import '../widgets/smart_bottom_nav.dart';
import 'detail_screen.dart';

/// Dashboard — mirrors `DashboardScreen` in
/// `implementation_plan/mobile_design_docs/screens.jsx` (lines 250-508).
class DashboardScreen extends ConsumerWidget {
  final VoidCallback? onOpenInsights;
  final VoidCallback? onOpenDevices;
  final VoidCallback? onAddDevice;
  const DashboardScreen({
    super.key,
    this.onOpenInsights,
    this.onOpenDevices,
    this.onAddDevice,
  });

  // Quick-access tints from dashboard-widgets.jsx (oklch → sRGB approx).
  static const Color _tintDevices = Color(0xFF4A6CFF); // indigo
  static const Color _tintSchedule = Color(0xFFE07A2A); // amber
  static const Color _tintMaintain = Color(0xFFC75BAA); // magenta
  static const Color _tintAlerts = Color(0xFFE69A30); // orange
  // Optimize uses primary (theme-aware) — resolved below.

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plugsAsync = ref.watch(plugsProvider);
    final settings = ref.watch(settingsProvider).valueOrNull;
    final scheme = Theme.of(context).colorScheme;
    final hasError = plugsAsync.hasError;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (hasError)
              ConnectionBanner(
                onRetry: () => ref.read(plugsProvider.notifier).refresh(),
              ),
            _GreetingHeader(
              onRefresh: () => ref.read(plugsProvider.notifier).refresh(),
              unreadAlerts: 2,
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.read(plugsProvider.notifier).refresh(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.l,
                    AppSpacing.xs,
                    AppSpacing.l,
                    AppSpacing.xxl,
                  ),
                  children: [
                    _hero(context, plugsAsync.valueOrNull ?? const []),
                    const SizedBox(height: 22),
                    const SectionHeader(title: 'Quick access'),
                    const SizedBox(height: AppSpacing.s),
                    _quickAccess(context, scheme),
                    const SizedBox(height: 24),
                    SectionHeader(
                      title: 'Your plugs',
                      trailing: 'updated just now',
                      trailingIsMono: true,
                    ),
                    const SizedBox(height: AppSpacing.s),
                    _plugs(context, ref, plugsAsync),
                    const SizedBox(height: 24),
                    SectionHeader(
                      title: 'Insights & alerts',
                      trailing: 'View all',
                      onTrailingTap: onOpenInsights,
                    ),
                    const SizedBox(height: AppSpacing.s),
                    ..._insights(context, plugsAsync.valueOrNull ?? const []),
                    const SizedBox(height: 18),
                    _connectionFooter(context, settings?.haUrl),
                    const SizedBox(height: AppSpacing.l),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero(BuildContext context, List<Plug> plugs) {
    // Whole-home figure: plug totals + "other appliances" baseline, matching
    // app.jsx (`energyToday = plugs.reduce(...) + 17.1`).
    final plugKwh = plugs.fold<double>(
      0,
      (acc, p) => acc + (p.energyTodayKwh ?? 0),
    );
    final totalKwh = plugKwh + DemoData.otherAppliancesKwh;
    // Synthetic 24-pt hourly trend (morning + evening peaks) until HA
    // long-term history is wired — mirrors app.jsx dayHistory().
    final hourly = List<double>.generate(24, (i) {
      final base = 0.4;
      final morning = 0.25 * _gauss((i - 8) / 2.5);
      final evening = 0.45 * _gauss((i - 19) / 2.8);
      final ripple = 0.06 * (i.isEven ? 1 : -1);
      return (base + morning + evening + ripple).clamp(0.1, double.infinity);
    });
    return EnergyHeroCard(
      kwh: totalKwh,
      deltaKwhPct: -12,
      cost: totalKwh * 0.27,
      deltaCostPct: -8,
      history: hourly,
    );
  }

  double _gauss(double x) => 1.0 / (x * x + 1);

  Widget _quickAccess(BuildContext context, ColorScheme scheme) {
    final tiles = <Map<String, dynamic>>[
      {
        'icon': AppIcons.devices,
        'label': 'Devices',
        'tint': _tintDevices,
        'onTap': onOpenDevices,
      },
      {
        'icon': AppIcons.schedule,
        'label': 'Schedule',
        'tint': _tintSchedule,
        'onTap': null,
      },
      {
        'icon': AppIcons.wrench,
        'label': 'Maintain',
        'tint': _tintMaintain,
        'onTap': null,
      },
      {
        'icon': AppIcons.warn,
        'label': 'Alerts',
        'tint': _tintAlerts,
        'onTap': onOpenInsights,
      },
      {
        'icon': AppIcons.leaf,
        'label': 'Optimize',
        'tint': scheme.primary,
        'onTap': null,
      },
    ];
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: tiles.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.s),
        itemBuilder: (_, i) {
          final t = tiles[i];
          return QuickAccessTile(
            icon: t['icon'],
            label: t['label'] as String,
            tint: t['tint'] as Color,
            onTap: t['onTap'] as VoidCallback?,
          );
        },
      ),
    );
  }

  Widget _plugs(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Plug>> async,
  ) {
    return async.when(
      data: (plugs) {
        if (plugs.isEmpty) return _emptyPlugs(context);
        return Column(
          children: [
            for (final p in plugs) ...[
              PlugCard(
                plug: p,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => DetailScreen(plugId: p.id)),
                ),
                onToggle: (_) async {
                  final ok =
                      await ref.read(plugsProvider.notifier).toggle(p.id);
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Couldn't reach Home Assistant"),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
      loading: () => Column(
        children: const [
          PlugCardSkeleton(),
          SizedBox(height: 10),
          PlugCardSkeleton(),
        ],
      ),
      error: (_, __) => _emptyPlugs(context),
    );
  }

  Widget _emptyPlugs(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Row(
        children: [
          HugeIcon(
            icon: AppIcons.otherPlug,
            color: scheme.onSurfaceVariant,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Text(
              'No plugs yet. Tap the + button below to add one.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _insights(BuildContext context, List<Plug> plugs) {
    // Tints from screens.jsx (lines 411-433).
    const tintBolt = Color(0xFFD8A12B); // oklch(0.6 0.16 60)
    const tintSchedule = Color(0xFF5A6FE0); // oklch(0.55 0.13 250)
    final tintLeaf = Theme.of(context).colorScheme.primary;

    return [
      InsightCard(
        icon: AppIcons.bolt,
        tint: tintBolt,
        title: 'Standby draw detected',
        description:
            'Radio drawing 7.8 W when likely idle — about £1.20/month wasted.',
        action: 'Check now',
        onTap: () {},
      ),
      const SizedBox(height: 8),
      InsightCard(
        icon: AppIcons.schedule,
        tint: tintSchedule,
        title: 'Off-peak window tonight',
        description:
            'Lowest tariff 00:30 – 04:30. Schedule heavy loads to save £0.12.',
        action: 'Save £0.12',
        onTap: () {},
      ),
      const SizedBox(height: 8),
      InsightCard(
        icon: AppIcons.leaf,
        tint: tintLeaf,
        title: 'Fridge running efficiently',
        description:
            'Compressor cycle is steady at 18 min — within normal range.',
        onTap: () {},
      ),
    ];
  }

  Widget _connectionFooter(BuildContext context, String? url) {
    final scheme = Theme.of(context).colorScheme;
    final host = _hostOf(url);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HugeIcon(
            icon: AppIcons.link,
            size: 12,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 6),
          Text(
            host ?? '100.83.45.15:8123',
            style: AppTheme.monoStyle(scheme).copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
              fontSize: 11,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '·',
              style: TextStyle(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ),
          Text(
            'via Tailscale',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
          ),
        ],
      ),
    );
  }

  String? _hostOf(String? url) {
    if (url == null) return null;
    try {
      final uri = Uri.parse(url);
      return uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
    } catch (_) {
      return url;
    }
  }
}

/// Greeting header (replaces standard AppBar on Home) — mirrors JSX lines
/// 304-329 in screens.jsx.
class _GreetingHeader extends StatefulWidget {
  final VoidCallback onRefresh;
  final int unreadAlerts;
  const _GreetingHeader({required this.onRefresh, this.unreadAlerts = 0});

  @override
  State<_GreetingHeader> createState() => _GreetingHeaderState();
}

class _GreetingHeaderState extends State<_GreetingHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  void _onRefresh() {
    _spin
      ..value = 0
      ..forward();
    widget.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : (hour < 18 ? 'Good afternoon' : 'Good evening');

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.m,
        AppSpacing.s,
        AppSpacing.s,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '$greeting, Alex',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontSize: 22,
                            height: 1.15,
                          ),
                    ),
                    const SizedBox(width: 6),
                    const Text('👋', style: TextStyle(fontSize: 20)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  "Here's your energy overview today",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _onRefresh,
            icon: RotationTransition(
              turns: _spin,
              child: HugeIcon(
                icon: AppIcons.refresh,
                size: 22,
                color: scheme.onSurface,
              ),
            ),
          ),
          _BellWithBadge(unread: widget.unreadAlerts),
        ],
      ),
    );
  }
}

class _BellWithBadge extends StatelessWidget {
  final int unread;
  const _BellWithBadge({required this.unread});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {},
            icon: HugeIcon(
              icon: AppIcons.bell,
              size: 22,
              color: scheme.onSurface,
            ),
          ),
          if (unread > 0)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                width: 16,
                height: 16,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.error,
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.surface, width: 2),
                ),
                child: Text(
                  '$unread',
                  style: TextStyle(
                    color: scheme.onError,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
