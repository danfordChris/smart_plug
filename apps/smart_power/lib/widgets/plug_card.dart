import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../config/app_icons.dart';
import '../config/theme.dart';
import '../models/plug.dart';
import '../utils/formatters.dart';
import 'mini_bars.dart';

/// PlugCard — mirrors `PlugCard` in
/// `implementation_plan/mobile_design_docs/widgets.jsx` (lines 78-148).
///
/// Layout (vertical):
///   Row 1: 56×56 glyph container · name + dot/entity_id stack · M3 Switch
///   Row 2: big power readout (44px Outfit) · MiniBars (last 16 readings)
class PlugCard extends StatelessWidget {
  final Plug plug;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTap;

  const PlugCard({
    super.key,
    required this.plug,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final on = plug.isOn;
    final unavailable = plug.isUnavailable;

    return Semantics(
      label: '${plug.name} plug, '
          '${unavailable ? 'unavailable' : (on ? 'on' : 'off')}. '
          'Power ${Fmt.power(plug.powerW)}. '
          'Tap to view details, or use the switch to '
          '${on ? 'turn off' : 'turn on'}.',
      container: true,
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Row 1: glyph + identity + switch ─────────────────
                Row(
                  children: [
                    Hero(
                      tag: 'plug-${plug.id}',
                      child: AnimatedContainer(
                        duration: AppMotion.cardGlyph,
                        curve: AppMotion.emphasized,
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: on
                              ? scheme.primaryContainer
                              : scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: HugeIcon(
                            icon: _glyphFor(plug.type),
                            size: 30,
                            color: on
                                ? scheme.onPrimaryContainer
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plug.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontSize: 20,
                                  height: 1.1,
                                  letterSpacing: -0.2,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              _Dot(
                                state: unavailable
                                    ? _DotState.unavailable
                                    : (on ? _DotState.on : _DotState.off),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  unavailable
                                      ? 'Unavailable'
                                      : '${on ? 'On' : 'Off'} · ${plug.entityId}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: on,
                      onChanged: unavailable ? null : onToggle,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // ── Row 2: big power readout + MiniBars ──────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            unavailable
                                ? '—'
                                : (plug.powerW == null
                                    ? '—'
                                    : plug.powerW!.toStringAsFixed(1)),
                            style: Theme.of(context)
                                .textTheme
                                .displayMedium
                                ?.copyWith(
                                  fontSize: 44,
                                  height: 1,
                                  color: unavailable || !on
                                      ? scheme.outline
                                      : scheme.onSurface,
                                ),
                          ),
                          const SizedBox(width: 6),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              'W',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontSize: 14,
                                    color: scheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    MiniBars(
                      values: plug.history,
                      active: on && !unavailable,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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

/// Skeleton placeholder shown while plugs load (Handoff §3).
class PlugCardSkeleton extends StatelessWidget {
  const PlugCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerLow;
    final fg = scheme.surfaceContainerHigh;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: fg,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 100, height: 18, color: fg),
                    const SizedBox(height: 8),
                    Container(width: 140, height: 12, color: fg),
                  ],
                ),
              ),
              Container(
                width: 52,
                height: 32,
                decoration: BoxDecoration(
                  color: fg,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(width: 80, height: 36, color: fg),
              Container(width: 60, height: 24, color: fg),
            ],
          ),
        ],
      ),
    );
  }
}

enum _DotState { on, off, unavailable }

/// Inline status dot used in the plug card identity row. Matches the `.dot`
/// rule in styles.css.
class _Dot extends StatelessWidget {
  final _DotState state;
  const _Dot({required this.state});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color color = switch (state) {
      _DotState.on => AppStatus.success,
      _DotState.off => scheme.outline,
      _DotState.unavailable => scheme.error,
    };
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
