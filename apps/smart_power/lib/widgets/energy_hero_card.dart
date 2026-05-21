import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../config/app_icons.dart';
import '../config/theme.dart';
import 'sparkline.dart';

/// Energy hero card — mirrors `EnergyHero` in
/// `implementation_plan/mobile_design_docs/dashboard-widgets.jsx` (lines 7-97).
///
/// Two-column grid:
///   LEFT — "Today's energy" label · big kWh value + delta · "vs yesterday" sub
///        · sparkline · time axis (12 AM / 6 AM / 12 PM / 6 PM / 12 AM)
///   DIVIDER (vertical hairline)
///   RIGHT — "Estimated cost" label · currency value + delta · "vs yesterday"
///         · "View report" tonal button
class EnergyHeroCard extends StatelessWidget {
  final double kwh;
  final double deltaKwhPct;
  final double cost;
  final double deltaCostPct;
  final String costCurrency;
  final List<double> history; // 24 points expected
  final VoidCallback? onReport;

  const EnergyHeroCard({
    super.key,
    required this.kwh,
    required this.deltaKwhPct,
    required this.cost,
    required this.deltaCostPct,
    required this.history,
    this.costCurrency = '£',
    this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fgMuted = scheme.onPrimary.withValues(alpha: 0.78);

    return Container(
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(AppRadii.cardLarge),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            // ── LEFT column — energy + sparkline ─────────────────────
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Label(text: "Today's energy", color: fgMuted),
                  const SizedBox(height: 4),
                  _ValueWithDelta(
                    value: kwh.toStringAsFixed(1),
                    unit: 'kWh',
                    deltaPct: deltaKwhPct,
                    primaryColor: scheme.onPrimary,
                    mutedColor: fgMuted,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'vs yesterday',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: fgMuted,
                          fontSize: 11,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  SizedBox(
                    height: 44,
                    child: HeroSparkline(
                      values: history,
                      lineColor: scheme.onPrimary,
                      gradientStart:
                          scheme.onPrimary.withValues(alpha: 0.35),
                      gradientEnd: scheme.onPrimary.withValues(alpha: 0),
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Time axis labels — match JSX (12AM / 6AM / 12PM / 6PM / 12AM)
                  DefaultTextStyle(
                    style: AppTheme.monoStyle(scheme).copyWith(
                      color: fgMuted,
                      fontSize: 9,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('12 AM'),
                        Text('6 AM'),
                        Text('12 PM'),
                        Text('6 PM'),
                        Text('12 AM'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // ── DIVIDER ──────────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.l),
              child: Container(
                width: 1,
                height: 132,
                color: scheme.onPrimary.withValues(alpha: 0.22),
              ),
            ),
            // ── RIGHT column — cost ──────────────────────────────────
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Label(text: 'Estimated cost', color: fgMuted),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        costCurrency,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                              color: scheme.onPrimary.withValues(alpha: 0.85),
                              fontSize: 22,
                            ),
                      ),
                      Text(
                        cost.toStringAsFixed(2),
                        style: Theme.of(context)
                            .textTheme
                            .displayMedium
                            ?.copyWith(
                              color: scheme.onPrimary,
                              fontSize: 32,
                              height: 1,
                            ),
                      ),
                      const SizedBox(width: 4),
                      _DeltaPill(
                        deltaPct: deltaCostPct,
                        color: scheme.onPrimary,
                        bg: scheme.onPrimary.withValues(alpha: 0.16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'vs yesterday',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: fgMuted,
                          fontSize: 11,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  // View report tonal button (matches .hero-card-report)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Material(
                      color: scheme.onPrimary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: onReport,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              HugeIcon(
                                icon: AppIcons.energy,
                                size: 14,
                                color: scheme.onPrimary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'View report',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      color: scheme.onPrimary,
                                      fontSize: 13,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  final Color color;
  const _Label({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontSize: 11,
            letterSpacing: 0.4,
          ),
    );
  }
}

class _ValueWithDelta extends StatelessWidget {
  final String value;
  final String unit;
  final double deltaPct;
  final Color primaryColor;
  final Color mutedColor;

  const _ValueWithDelta({
    required this.value,
    required this.unit,
    required this.deltaPct,
    required this.primaryColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: primaryColor,
                fontSize: 36,
                height: 1,
              ),
        ),
        const SizedBox(width: 4),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            unit,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: mutedColor,
                  fontSize: 14,
                ),
          ),
        ),
        const SizedBox(width: 6),
        _DeltaPill(
          deltaPct: deltaPct,
          color: primaryColor,
          bg: scheme.onPrimary.withValues(alpha: 0.16),
        ),
      ],
    );
  }
}

class _DeltaPill extends StatelessWidget {
  final double deltaPct;
  final Color color;
  final Color bg;
  const _DeltaPill({
    required this.deltaPct,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    final down = deltaPct < 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: down ? AppIcons.arrowDown : AppIcons.arrowUp,
            size: 10,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            '${deltaPct.abs().toStringAsFixed(0)}%',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
