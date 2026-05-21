import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../config/app_icons.dart';
import '../config/theme.dart';
import '../models/plug.dart';
import '../providers/plugs_provider.dart';
import '../utils/formatters.dart';
import '../widgets/insight_card.dart';
import '../widgets/smart_bottom_nav.dart';
import '../widgets/sparkline.dart';

/// Insights — mirrors `InsightsScreen` in
/// `implementation_plan/mobile_design_docs/screens.jsx` (lines 774-938).
///
/// Weekly chart card (kWh + cost + 7 bars) · Top appliances today (% of
/// total) · Recommendations (4 InsightCards).
class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  // Recommendation tints (oklch → sRGB) from screens.jsx lines 902-933.
  static const Color _tintMaintain = Color(0xFFC2602B); // oklch(0.6 0.16 30)
  static const Color _tintSchedule = Color(0xFF5A6FE0); // oklch(0.55 0.13 250)
  static const Color _tintLoss = Color(0xFFD8A12B); // oklch(0.6 0.16 60)

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final plugs = ref.watch(plugsProvider).valueOrNull ?? const <Plug>[];
    final weekly = _syntheticWeek(plugs);
    final todayIndex = DateTime.now().weekday - 1;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: const Text('Insights')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.xs,
          AppSpacing.l,
          AppSpacing.xxl,
        ),
        physics: const BouncingScrollPhysics(),
        children: [
          _weeklyCard(context, weekly, todayIndex),
          const SizedBox(height: AppSpacing.l),
          const SectionHeader(title: 'Top appliances today'),
          const SizedBox(height: AppSpacing.s),
          _breakdownCard(context, plugs),
          const SizedBox(height: AppSpacing.l),
          const SectionHeader(title: 'Recommendations'),
          const SizedBox(height: AppSpacing.s),
          InsightCard(
            icon: AppIcons.wrench,
            tint: _tintMaintain,
            title: 'Predictive maintenance',
            description:
                'Fridge compressor cycle drifting slightly longer. Service within 30 days.',
            action: 'High',
            actionColor: _tintMaintain,
          ),
          const SizedBox(height: 8),
          InsightCard(
            icon: AppIcons.schedule,
            tint: _tintSchedule,
            title: 'Schedule suggestion',
            description: 'Run heavy loads 00:30 – 04:30 to use off-peak tariff.',
            action: 'Save £0.12',
            actionColor: _tintSchedule,
          ),
          const SizedBox(height: 8),
          InsightCard(
            icon: AppIcons.bolt,
            tint: _tintLoss,
            title: 'Energy loss detected',
            description:
                'Standby power loss of 0.8 kWh/day detected across all devices.',
            action: 'Check now',
            actionColor: _tintLoss,
          ),
          const SizedBox(height: 8),
          InsightCard(
            icon: AppIcons.leaf,
            tint: scheme.primary,
            title: 'Optimization tip',
            description:
                'Setting fridge to 4°C can save up to 8% energy without affecting freshness.',
            action: 'Learn more',
            actionColor: scheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _weeklyCard(
    BuildContext context,
    List<double> weekly,
    int todayIndex,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final totalKwh = weekly.fold<double>(0, (a, b) => a + b);
    final totalCost = totalKwh * 0.27;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.cardLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'THIS WEEK',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            letterSpacing: 0.5,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          totalKwh.toStringAsFixed(1),
                          style: Theme.of(context)
                              .textTheme
                              .displayMedium
                              ?.copyWith(fontSize: 28, height: 1),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'kWh',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Cost',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '£${totalCost.toStringAsFixed(2)}',
                    style: Theme.of(context)
                        .textTheme
                        .displayMedium
                        ?.copyWith(fontSize: 22, height: 1),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 130,
            child: WeeklyBarChart(
              dailyKwh: weekly,
              todayIndex: todayIndex,
            ),
          ),
        ],
      ),
    );
  }

  Widget _breakdownCard(BuildContext context, List<Plug> plugs) {
    final scheme = Theme.of(context).colorScheme;
    final sorted = [...plugs]
      ..sort((a, b) =>
          (b.energyTodayKwh ?? 0).compareTo(a.energyTodayKwh ?? 0));
    final total = sorted.fold<double>(0, (a, p) => a + (p.energyTodayKwh ?? 0));
    final safeTotal = total > 0 ? total : 1.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        children: [
          for (int i = 0; i < sorted.length; i++)
            _breakdownRow(
              context,
              sorted[i],
              ((sorted[i].energyTodayKwh ?? 0) / safeTotal * 100).round(),
              hasDivider: i < sorted.length - 1,
            ),
          if (sorted.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No data yet.',
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

  Widget _breakdownRow(
    BuildContext context,
    Plug p,
    int pct, {
    required bool hasDivider,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: hasDivider
          ? BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: scheme.outlineVariant,
                  width: 0.5,
                ),
              ),
            )
          : null,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: HugeIcon(
                icon: _glyphFor(p.type),
                size: 20,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        p.name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                    Text(
                      Fmt.energy(p.energyTodayKwh),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: pct / 100,
                    backgroundColor: scheme.surfaceContainerHigh,
                    valueColor: AlwaysStoppedAnimation(scheme.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 36,
            child: Text(
              '$pct%',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
          ),
        ],
      ),
    );
  }

  List<double> _syntheticWeek(List<Plug> plugs) {
    final today = plugs.fold<double>(0, (a, p) => a + (p.energyTodayKwh ?? 0));
    // Match app.jsx weekHistory seed shape (Mon..Sun, today last).
    final seed = [16.4, 18.1, 15.2, 19.8, 17.6, 14.5, today + 17.1];
    return seed;
  }

  static dynamic _glyphFor(ApplianceType t) {
    switch (t) {
      case ApplianceType.radio:
        return AppIcons.radio;
      case ApplianceType.fridge:
        return AppIcons.fridge;
      case ApplianceType.heater:
        return AppIcons.heater;
      case ApplianceType.airConditioner:
        return AppIcons.airConditioner;
      case ApplianceType.washer:
        return AppIcons.washer;
      case ApplianceType.waterHeater:
        return AppIcons.waterHeater;
      case ApplianceType.light:
        return AppIcons.light;
      case ApplianceType.other:
        return AppIcons.otherPlug;
    }
  }
}
