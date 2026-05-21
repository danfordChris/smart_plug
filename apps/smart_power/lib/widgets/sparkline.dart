import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Hero sparkline (Handoff §5).
/// Renders 24 points (hourly kWh on the dashboard hero card) over a tinted
/// fill that fades toward the bottom.
class HeroSparkline extends StatelessWidget {
  final List<double> values;
  final Color lineColor;
  final Color gradientStart;
  final Color gradientEnd;

  const HeroSparkline({
    super.key,
    required this.values,
    required this.lineColor,
    required this.gradientStart,
    required this.gradientEnd,
  });

  @override
  Widget build(BuildContext context) {
    final spots = values
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();
    return LineChart(
      LineChartData(
        minY: 0,
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            barWidth: 1.6,
            color: lineColor,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [gradientStart, gradientEnd],
              ),
            ),
          ),
        ],
      ),
      duration: AppMotion.sparkline,
    );
  }
}

/// Detail-screen sparkline. 60 points, primary color, with the last point
/// drawn as a contrast dot (Handoff §5).
class DetailSparkline extends StatelessWidget {
  final List<double> values;
  const DetailSparkline({super.key, required this.values});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (values.isEmpty) {
      return Center(
        child: Text(
          'Collecting data…',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    }
    final spots = values
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();
    final lastIndex = (values.length - 1).toDouble();
    return LineChart(
      LineChartData(
        minY: 0,
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            barWidth: 2,
            color: scheme.primary,
            dotData: FlDotData(
              show: true,
              checkToShowDot: (s, _) => s.x == lastIndex,
              getDotPainter: (s, _, __, ___) => FlDotCirclePainter(
                radius: 3.5,
                color: scheme.surface,
                strokeColor: scheme.primary,
                strokeWidth: 2,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scheme.primary.withValues(alpha: 0.18),
                  scheme.primary.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ],
      ),
      duration: AppMotion.sparkline,
    );
  }
}

/// Weekly bar chart (Handoff §5). 7 bars, today highlighted.
class WeeklyBarChart extends StatelessWidget {
  final List<double> dailyKwh; // length 7, Mon..Sun
  final int todayIndex;
  final List<String> labels;

  const WeeklyBarChart({
    super.key,
    required this.dailyKwh,
    required this.todayIndex,
    this.labels = const ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxV = dailyKwh.isEmpty
        ? 1.0
        : dailyKwh.reduce((a, b) => a > b ? a : b);
    final maxY = maxV * 1.15 + 0.0001;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceBetween,
        maxY: maxY,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= labels.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    labels[i],
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(
          dailyKwh.length,
          (i) => BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: dailyKwh[i],
                color: i == todayIndex
                    ? scheme.primary
                    : scheme.primary.withValues(alpha: 0.35),
                width: 28,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
