import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../config/theme.dart';

/// QuickAccessTile — mirrors `QuickTile` in
/// `implementation_plan/mobile_design_docs/dashboard-widgets.jsx` (lines 102-109)
/// and `.qa-tile` rule in styles.css.
///
/// 88×92 button with rounded icon container at top and label beneath. The
/// caller picks the tint per the JSX prototype (Devices indigo, Schedule
/// amber, Maintain magenta, Alerts orange, Optimize primary green).
class QuickAccessTile extends StatelessWidget {
  final dynamic icon; // HugeIcons.* (List<List<dynamic>>)
  final String label;
  final Color tint;
  final VoidCallback? onTap;

  const QuickAccessTile({
    super.key,
    required this.icon,
    required this.label,
    required this.tint,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: SizedBox(
          width: 88,
          height: 92,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: HugeIcon(icon: icon, size: 20, color: tint),
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurface,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
