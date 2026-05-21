import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../config/app_icons.dart';
import '../config/theme.dart';
import '../models/plug.dart';
import '../providers/plugs_provider.dart';
import '../utils/formatters.dart';
import '../widgets/sparkline.dart';
import '../widgets/stat_tile.dart';

/// Detail screen — mirrors `DetailScreen` in
/// `implementation_plan/mobile_design_docs/screens.jsx` (lines 513-...).
///
/// Centered hero: 96×96 glyph in tinted square · name · dot + entity_id.
/// Big switch panel underneath (full-width, primary bg when on).
/// 2×2 stat grid · sparkline card with peak/avg metadata · hint card.
class DetailScreen extends ConsumerWidget {
  final String plugId;
  const DetailScreen({super.key, required this.plugId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plugs = ref.watch(plugsProvider).valueOrNull ?? const <Plug>[];
    final plug = plugs.cast<Plug?>().firstWhere(
          (p) => p?.id == plugId,
          orElse: () => null,
        );
    final scheme = Theme.of(context).colorScheme;

    if (plug == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).pop(),
            icon: HugeIcon(
              icon: AppIcons.arrowBack,
              size: 22,
              color: scheme.onSurface,
            ),
          ),
        ),
        body: const Center(child: Text('Plug not found')),
      );
    }

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          icon: HugeIcon(
            icon: AppIcons.arrowBack,
            size: 22,
            color: scheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () {},
            icon: HugeIcon(
              icon: AppIcons.settings,
              size: 22,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _heroIdentity(context, plug, scheme),
              const SizedBox(height: AppSpacing.l),
              _bigSwitchPanel(context, ref, plug),
              const SizedBox(height: AppSpacing.l),
              _statGrid(context, plug),
              const SizedBox(height: AppSpacing.l),
              _sparklineCard(context, plug),
              if (plug.type.isCriticalLoad) ...[
                const SizedBox(height: AppSpacing.m),
                _criticalCard(context, plug.type.label),
              ],
              const SizedBox(height: AppSpacing.m),
              _hintCard(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroIdentity(BuildContext context, Plug plug, ColorScheme scheme) {
    final on = plug.isOn;
    final unavailable = plug.isUnavailable;
    final glyph = _glyphFor(plug.type);
    return Column(
      children: [
        Hero(
          tag: 'plug-${plug.id}',
          child: AnimatedContainer(
            duration: AppMotion.bigSwitchPanel,
            curve: AppMotion.emphasized,
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: on
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppRadii.heroIcon),
            ),
            child: Center(
              child: HugeIcon(
                icon: glyph,
                size: 52,
                color: on
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.l),
        Text(
          plug.name,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontSize: 32,
                letterSpacing: -0.5,
                height: 1,
              ),
        ),
        const SizedBox(height: AppSpacing.s),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: unavailable
                    ? scheme.error
                    : (on ? AppStatus.success : scheme.outline),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              plug.entityId,
              style: AppTheme.monoStyle(scheme).copyWith(fontSize: 13),
            ),
          ],
        ),
      ],
    );
  }

  Widget _bigSwitchPanel(BuildContext context, WidgetRef ref, Plug plug) {
    final scheme = Theme.of(context).colorScheme;
    final on = plug.isOn;
    final unavailable = plug.isUnavailable;
    final bg = on ? scheme.primary : scheme.surfaceContainerLow;
    final fg = on ? scheme.onPrimary : scheme.onSurface;
    final fgMuted = on
        ? scheme.onPrimary.withValues(alpha: 0.8)
        : scheme.onSurfaceVariant;
    return Semantics(
      label: '${plug.name} plug, '
          '${unavailable ? 'unavailable' : (on ? 'on' : 'off')}. '
          'Tap the switch to ${on ? 'turn off' : 'turn on'}.',
      container: true,
      child: AnimatedContainer(
        duration: AppMotion.bigSwitchPanel,
        curve: AppMotion.emphasized,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadii.cardLarge),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    unavailable ? 'Unavailable' : (on ? 'On' : 'Off'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontSize: 22,
                          color: fg,
                          letterSpacing: -0.2,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    unavailable
                        ? 'Check the device'
                        : 'Tap to turn ${on ? 'off' : 'on'}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: fgMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
            Switch(
              value: on,
              onChanged: unavailable
                  ? null
                  : (_) async {
                      final ok = await ref
                          .read(plugsProvider.notifier)
                          .toggle(plug.id);
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Couldn't reach Home Assistant"),
                          ),
                        );
                      }
                    },
              thumbColor:
                  on ? WidgetStatePropertyAll(scheme.primary) : null,
              trackColor:
                  on ? WidgetStatePropertyAll(scheme.onPrimary) : null,
              trackOutlineColor:
                  on ? WidgetStatePropertyAll(scheme.onPrimary) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statGrid(BuildContext context, Plug plug) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: AppSpacing.m,
      crossAxisSpacing: AppSpacing.m,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      childAspectRatio: 1.45,
      children: [
        StatTile(
          label: 'Power',
          value: Fmt.powerValue(plug.powerW),
          unit: 'W',
          icon: AppIcons.power,
          accent: plug.isOn,
        ),
        StatTile(
          label: 'Voltage',
          value: plug.voltageV == null
              ? '—'
              : plug.voltageV!.toStringAsFixed(0),
          unit: 'V',
          icon: AppIcons.voltage,
        ),
        StatTile(
          label: 'Current',
          value: plug.currentA == null
              ? '—'
              : plug.currentA!.toStringAsFixed(3),
          unit: 'A',
          icon: AppIcons.current,
        ),
        StatTile(
          label: 'Today',
          value: Fmt.energyValue(plug.energyTodayKwh),
          unit: 'kWh',
          icon: AppIcons.energy,
        ),
      ],
    );
  }

  Widget _sparklineCard(BuildContext context, Plug plug) {
    final scheme = Theme.of(context).colorScheme;
    final values = plug.history;
    final max = values.isEmpty
        ? 0.0
        : values.reduce((a, b) => a > b ? a : b);
    final avg = values.isEmpty
        ? 0.0
        : values.reduce((a, b) => a + b) / values.length;
    final last = values.isEmpty ? 0.0 : values.last;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      padding: const EdgeInsets.all(AppSpacing.l),
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
                      'POWER · LAST 60 MIN',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            letterSpacing: 0.5,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          last.toStringAsFixed(1),
                          style: Theme.of(context)
                              .textTheme
                              .displayMedium
                              ?.copyWith(
                                fontSize: 22,
                                height: 1,
                                color: scheme.onSurface,
                              ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'W now',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
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
                    'peak ${max.toStringAsFixed(1)} W',
                    style: AppTheme.monoStyle(scheme).copyWith(fontSize: 11),
                  ),
                  Text(
                    'avg ${avg.toStringAsFixed(1)} W',
                    style: AppTheme.monoStyle(scheme).copyWith(fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
          SizedBox(height: 100, child: DetailSparkline(values: values)),
          const SizedBox(height: 4),
          DefaultTextStyle(
            style: AppTheme.monoStyle(scheme).copyWith(
              fontSize: 10,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('−60m'),
                Text('−45m'),
                Text('−30m'),
                Text('−15m'),
                Text('now'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _criticalCard(BuildContext context, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(icon: AppIcons.warn, size: 20, color: scheme.error),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Text(
              'Critical load: $label. Idle-detection auto-off is disabled '
              'for this plug to prevent food spoilage / safety issues.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onErrorContainer,
                    height: 1.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hintCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(
            icon: AppIcons.help,
            size: 18,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Text(
              'Name and icon mirror what you set in Home Assistant. Edit the '
              'entity there and changes show up after a refresh.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.5,
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
