import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../config/app_icons.dart';
import '../config/theme.dart';

/// InsightCard — mirrors `InsightCard` in
/// `implementation_plan/mobile_design_docs/dashboard-widgets.jsx` (lines 114-135).
///
/// Layout: tinted square icon · title + description (stack) · action chevron.
/// Tint controls icon container background (18% of tint) AND icon color.
/// Action label is optional; when present a small chevron appears.
class InsightCard extends StatelessWidget {
  final dynamic icon; // HugeIcons.* (List<List<dynamic>>)
  final Color tint;
  final String title;
  final String description;
  final String? action;
  final Color? actionColor;
  final VoidCallback? onTap;

  const InsightCard({
    super.key,
    required this.icon,
    required this.tint,
    required this.title,
    required this.description,
    this.action,
    this.actionColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final aColor = actionColor ?? tint;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: HugeIcon(icon: icon, size: 20, color: tint),
                ),
              ),
              const SizedBox(width: AppSpacing.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 15,
                            color: scheme.onSurface,
                            height: 1.2,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
                    ),
                  ],
                ),
              ),
              if (action != null) ...[
                const SizedBox(width: AppSpacing.s),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      action!,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: aColor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(width: 2),
                    HugeIcon(
                      icon: AppIcons.chevronRight,
                      size: 14,
                      color: aColor,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
