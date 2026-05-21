import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Tiny inline bar graph used inside [PlugCard].
///
/// Mirror of the `MiniBars` widget from
/// `implementation_plan/mobile_design_docs/widgets.jsx` (lines 151-172):
/// last 16 readings, height 28, bar width 3, 2 px gap, opacity ramped
/// 0.4 → 1.0 left-to-right, primary color when `active` else outlineVariant.
class MiniBars extends StatelessWidget {
  final List<double> values;
  final bool active;
  final int bars;
  final double height;

  const MiniBars({
    super.key,
    required this.values,
    required this.active,
    this.bars = 16,
    this.height = 28,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color color = active ? scheme.primary : scheme.outlineVariant;

    final tail = values.length <= bars
        ? values
        : values.sublist(values.length - bars);
    final max = tail.fold<double>(0, (a, b) => b > a ? b : a);
    final safeMax = max > 0 ? max : 1.0;

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: List.generate(bars, (i) {
          final idx = i - (bars - tail.length);
          final v = idx >= 0 && idx < tail.length ? tail[idx] : 0.0;
          final h = (v / safeMax) * height;
          final opacity = 0.4 + (i / bars) * 0.6;
          return Padding(
            padding: EdgeInsets.only(right: i == bars - 1 ? 0 : 2),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              curve: AppMotion.emphasized,
              width: 3,
              height: h < 2 ? 2 : h,
              decoration: BoxDecoration(
                color: color.withValues(alpha: opacity),
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          );
        }),
      ),
    );
  }
}
