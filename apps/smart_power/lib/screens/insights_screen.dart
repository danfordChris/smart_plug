import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../config/app_icons.dart';
import '../config/theme.dart';
import '../models/diagnosis.dart';
import '../models/plug.dart';
import '../models/usage.dart';
import '../providers/diagnosis_provider.dart';
import '../providers/plugs_provider.dart';
import '../providers/usage_provider.dart';
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
  static const Color _tintSchedule = Color(0xFF5A6FE0); // oklch(0.55 0.13 250)
  static const Color _tintLoss = Color(0xFFD8A12B); // oklch(0.6 0.16 60)

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final plugs = ref.watch(plugsProvider).valueOrNull ?? const <Plug>[];
    final period = ref.watch(usagePeriodProvider);
    // Real series when signed in; synthetic fallback keeps the chart populated.
    final series = ref.watch(usageProvider(period)).valueOrNull ??
        syntheticUsage(period, plugs);

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
          _usageCard(context, ref, series),
          const SizedBox(height: AppSpacing.l),
          SectionHeader(title: 'Top appliances ${period.noun}'),
          const SizedBox(height: AppSpacing.s),
          _breakdownCard(context, plugs, series),
          const SizedBox(height: AppSpacing.l),
          const SectionHeader(title: 'Recommendations'),
          const SizedBox(height: AppSpacing.s),
          ..._recommendations(context, ref, plugs),
        ],
      ),
    );
  }

  static String _periodHeader(UsagePeriod p) {
    switch (p) {
      case UsagePeriod.original:
        return 'OVERVIEW';
      case UsagePeriod.day:
        return 'TODAY';
      default:
        return 'THIS ${p.label.toUpperCase()}';
    }
  }

  /// Real, diagnosis-derived recommendations when signed in; the curated tips
  /// otherwise (demo/preview) so the section is never empty.
  List<Widget> _recommendations(BuildContext context, WidgetRef ref, List<Plug> plugs) {
    final scheme = Theme.of(context).colorScheme;
    final flagged = ref.watch(flaggedDiagnosesProvider).valueOrNull ?? const <Diagnosis>[];
    final nameByEntity = {for (final p in plugs) p.entityId: p.name};

    if (flagged.isNotEmpty) {
      Color tint(String sev) => sev == 'critical'
          ? scheme.error
          : sev == 'warning'
              ? _tintLoss
              : _tintSchedule;
      final cards = <Widget>[];
      for (final d in flagged) {
        final name = nameByEntity[d.entityId] ?? d.entityId.split('.').last;
        cards.add(InsightCard(
          icon: d.severity == 'info' ? AppIcons.leaf : AppIcons.wrench,
          tint: tint(d.severity),
          title: name,
          description: d.explanation,
          action: d.statusLabel,
          actionColor: tint(d.severity),
        ));
        cards.add(const SizedBox(height: 8));
      }
      if (cards.isNotEmpty) cards.removeLast();
      return cards;
    }

    // No live issues (or not signed in) → keep a couple of generic tips.
    return [
      InsightCard(
        icon: AppIcons.check,
        tint: scheme.primary,
        title: 'All appliances healthy',
        description:
            'No faults, abnormal draw, or cost spikes detected across your plugs.',
        action: 'Good',
        actionColor: scheme.primary,
      ),
      const SizedBox(height: 8),
      InsightCard(
        icon: AppIcons.leaf,
        tint: scheme.primary,
        title: 'Optimization tip',
        description:
            'Setting a fridge to 4°C can save up to 8% energy without affecting freshness.',
        action: 'Learn more',
        actionColor: scheme.primary,
      ),
    ];
  }

  Widget _usageCard(BuildContext context, WidgetRef ref, UsageSeries series) {
    final scheme = Theme.of(context).colorScheme;
    final totalKwh = series.totalKwh;
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
                    // Period filter lives here (replaces the static "THIS WEEK").
                    DropdownButtonHideUnderline(
                      child: DropdownButton<UsagePeriod>(
                        value: series.period,
                        isDense: true,
                        borderRadius: BorderRadius.circular(AppRadii.card),
                        icon: Icon(Icons.keyboard_arrow_down_rounded,
                            size: 18, color: scheme.onSurfaceVariant),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              letterSpacing: 0.5,
                            ),
                        selectedItemBuilder: (context) => UsagePeriod.values
                            .map((p) => Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _periodHeader(series.period),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                          letterSpacing: 0.5,
                                        ),
                                  ),
                                ))
                            .toList(),
                        items: [
                          for (final p in UsagePeriod.values)
                            DropdownMenuItem(value: p, child: Text(p.label)),
                        ],
                        onChanged: (p) {
                          if (p != null) {
                            ref.read(usagePeriodProvider.notifier).state = p;
                          }
                        },
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
                    Fmt.cost(totalKwh),
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
              dailyKwh: series.values,
              todayIndex: series.currentIndex,
              labels: series.labels,
            ),
          ),
        ],
      ),
    );
  }

  Widget _breakdownCard(BuildContext context, List<Plug> plugs, UsageSeries series) {
    final scheme = Theme.of(context).colorScheme;
    // Per-plug kWh for the selected period (from the series' by_entity totals),
    // falling back to today's energy when no period totals are available.
    double kwhFor(Plug p) =>
        series.byEntity[p.entityId] ?? (p.energyTodayKwh ?? 0);
    final sorted = [...plugs]..sort((a, b) => kwhFor(b).compareTo(kwhFor(a)));
    final total = sorted.fold<double>(0, (a, p) => a + kwhFor(p));
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
              kwhFor(sorted[i]),
              (kwhFor(sorted[i]) / safeTotal * 100).round(),
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
    double kwh,
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
                      Fmt.energy(kwh),
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
