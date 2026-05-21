import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../config/theme.dart';

/// Stat tile (Detail screen 2×2 grid) — mirrors `StatTile` in
/// `implementation_plan/mobile_design_docs/widgets.jsx` (lines 195-220).
///
/// When `accent` is true, the tile uses the `primaryContainer` background
/// (per the JSX prototype's accent tone for the live Power reading).
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final dynamic icon; // HugeIcons.* (List<List<dynamic>>)
  final bool accent;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = accent ? scheme.primaryContainer : scheme.surfaceContainerLow;
    final fg = accent ? scheme.onPrimaryContainer : scheme.onSurface;
    final fgVariant = accent
        ? scheme.onPrimaryContainer.withValues(alpha: 0.85)
        : scheme.onSurfaceVariant;

    return AnimatedContainer(
      duration: AppMotion.statTile,
      curve: AppMotion.emphasized,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              HugeIcon(icon: icon, size: 16, color: fgVariant),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: fgVariant,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: fg,
                      fontSize: 32,
                      height: 1,
                    ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: fgVariant,
                        fontSize: 14,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
