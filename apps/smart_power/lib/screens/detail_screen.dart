import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../config/app_icons.dart';
import '../config/theme.dart';
import '../models/diagnosis.dart';
import '../models/plug.dart';
import '../providers/diagnosis_provider.dart';
import '../providers/plugs_provider.dart';
import '../utils/formatters.dart';
import '../widgets/sparkline.dart';
import '../widgets/stat_tile.dart';
import 'device_config_screen.dart';

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
    final plug = plugs.cast<Plug?>().firstWhere((p) => p?.id == plugId, orElse: () => null);
    final scheme = Theme.of(context).colorScheme;

    if (plug == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).pop(),
            icon: HugeIcon(icon: AppIcons.arrowBack, size: 22, color: scheme.onSurface),
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
          icon: HugeIcon(icon: AppIcons.arrowBack, size: 22, color: scheme.onSurface),
        ),
        actions: [
          IconButton(
            tooltip: 'Device settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DeviceConfigScreen(entityId: plug.entityId, plugName: plug.name),
              ),
            ),
            icon: HugeIcon(icon: AppIcons.settings, size: 22, color: scheme.onSurface),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _heroIdentity(context, plug, scheme),
              const SizedBox(height: AppSpacing.l),
              _bigSwitchPanel(context, ref, plug),
              const SizedBox(height: AppSpacing.m),
              _statusRow(context, plug),
              const SizedBox(height: AppSpacing.l),
              _statGrid(context, plug),
              const SizedBox(height: AppSpacing.l),
              _sparklineCard(context, plug),
              const SizedBox(height: AppSpacing.m),
              _diagnosisCard(context, ref, plug),
              if (plug.type.isCriticalLoad) ...[const SizedBox(height: AppSpacing.m), _criticalCard(context, plug.type.label)],
              const SizedBox(height: AppSpacing.m),
              _diagnosticsCard(context, plug),
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
              color: on ? scheme.primaryContainer : scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppRadii.heroIcon),
            ),
            child: Center(
              child: HugeIcon(icon: glyph, size: 52, color: on ? scheme.onPrimaryContainer : scheme.onSurfaceVariant),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.l),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              plug.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontSize: 32, letterSpacing: -0.5, height: 1),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: unavailable ? scheme.error : (on ? AppStatus.success : scheme.outline), shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(plug.entityId, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.monoStyle(scheme).copyWith(fontSize: 13)),
              ),
            ],
          ),
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
    final fgMuted = on ? scheme.onPrimary.withValues(alpha: 0.8) : scheme.onSurfaceVariant;
    return Semantics(
      label:
          '${plug.name} plug, '
          '${unavailable ? 'unavailable' : (on ? 'on' : 'off')}. '
          'Tap the switch to ${on ? 'turn off' : 'turn on'}.',
      container: true,
      child: AnimatedContainer(
        duration: AppMotion.bigSwitchPanel,
        curve: AppMotion.emphasized,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadii.cardLarge)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    unavailable ? 'Unavailable' : (on ? 'On' : 'Off'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 22, color: fg, letterSpacing: -0.2),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    unavailable ? 'Check the device' : 'Tap to turn ${on ? 'off' : 'on'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: fgMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
            Switch(
              value: on,
              onChanged: unavailable
                  ? null
                  : (_) async {
                      final ok = await ref.read(plugsProvider.notifier).toggle(plug.id);
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't reach Plug Assistance")));
                      }
                    },
              thumbColor: on ? WidgetStatePropertyAll(scheme.primary) : null,
              trackColor: on ? WidgetStatePropertyAll(scheme.onPrimary) : null,
              trackOutlineColor: on ? WidgetStatePropertyAll(scheme.onPrimary) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statGrid(BuildContext context, Plug plug) {
    // Core 4 are always shown (— when missing). Month/Total/WiFi appear only
    // when the device actually exposes them, so the grid stays honest.
    final tiles = <Widget>[
      StatTile(label: 'Power', value: Fmt.powerValue(plug.powerW), unit: 'W', icon: AppIcons.power, accent: plug.isOn),
      StatTile(label: 'Voltage', value: plug.voltageV == null ? '—' : plug.voltageV!.toStringAsFixed(0), unit: 'V', icon: AppIcons.voltage),
      StatTile(label: 'Current', value: plug.currentA == null ? '—' : plug.currentA!.toStringAsFixed(3), unit: 'A', icon: AppIcons.current),
      StatTile(label: 'Today', value: Fmt.energyValue(plug.energyTodayKwh), unit: 'kWh', icon: AppIcons.energy),
      if (plug.energyMonthKwh != null) StatTile(label: 'This month', value: Fmt.energyValue(plug.energyMonthKwh), unit: 'kWh', icon: AppIcons.energy),
      if (plug.energyTotalKwh != null) StatTile(label: 'Total', value: Fmt.energyValue(plug.energyTotalKwh), unit: 'kWh', icon: AppIcons.energy),
      if (plug.wifiRssiDbm != null) StatTile(label: 'WiFi', value: plug.wifiRssiDbm!.toStringAsFixed(0), unit: 'dBm', icon: AppIcons.wifi),
    ];
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: AppSpacing.m,
      crossAxisSpacing: AppSpacing.m,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      childAspectRatio: 1.45,
      children: tiles,
    );
  }

  /// Availability + last-seen strip. Surfaces online/offline plus when the
  /// state was last refreshed and last changed (HA `last_updated`/`last_changed`).
  Widget _statusRow(BuildContext context, Plug plug) {
    final scheme = Theme.of(context).colorScheme;
    final online = !plug.isUnavailable;
    return Container(
      decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(AppRadii.card)),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: AppSpacing.m),
      child: Row(
        children: [
          _statusChip(
            context,
            icon: online ? AppIcons.wifi : AppIcons.cloudOff,
            label: online ? 'Online' : 'Offline',
            color: online ? AppStatus.success : scheme.error,
          ),
          const Spacer(),
          _statusMeta(context, 'Updated', Fmt.relative(plug.lastUpdated)),
          const SizedBox(width: AppSpacing.l),
          _statusMeta(context, 'Changed', Fmt.relative(plug.lastChanged)),
        ],
      ),
    );
  }

  Widget _statusChip(BuildContext context, {required dynamic icon, required String label, required Color color}) {
    return Row(
      children: [
        HugeIcon(icon: icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _statusMeta(BuildContext context, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 0.5, fontSize: 10),
        ),
        const SizedBox(height: 2),
        Text(value, style: AppTheme.monoStyle(scheme).copyWith(fontSize: 12)),
      ],
    );
  }

  /// Collapsible diagnostics: every matched sensor's raw value + each
  /// entity's full HA attribute map. Full transparency — nothing hidden.
  Widget _diagnosticsCard(BuildContext context, Plug plug) {
    final scheme = Theme.of(context).colorScheme;
    final readings = plug.readings.values.toList()..sort((a, b) => a.entityId.compareTo(b.entityId));

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(AppRadii.card)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.l, 0, AppSpacing.l, AppSpacing.l),
          leading: HugeIcon(icon: AppIcons.wrench, size: 18, color: scheme.onSurfaceVariant),
          title: Text('Diagnostics', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15)),
          subtitle: Text(
            '${readings.length} sensor${readings.length == 1 ? '' : 's'} · '
            'raw Plug Assistance data',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          children: [
            // The backing switch entity.
            _entityBlock(
              context,
              title: plug.name,
              entityId: plug.entityId,
              valueLine: plug.isUnavailable ? 'unavailable' : (plug.isOn ? 'on' : 'off'),
              attributes: plug.attributes,
            ),
            for (final r in readings) ...[
              const SizedBox(height: AppSpacing.s),
              _entityBlock(context, title: r.friendlyName ?? r.entityId, entityId: r.entityId, valueLine: r.display, attributes: r.attributes),
            ],
          ],
        ),
      ),
    );
  }

  Widget _entityBlock(
    BuildContext context, {
    required String title,
    required String entityId,
    required String valueLine,
    required Map<String, dynamic> attributes,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final keys = attributes.keys.toList()..sort();
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(AppRadii.card)),
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall),
              ),
              const SizedBox(width: AppSpacing.s),
              Text(valueLine, style: AppTheme.monoStyle(scheme).copyWith(fontSize: 12, color: scheme.primary)),
            ],
          ),
          const SizedBox(height: 2),
          Text(entityId, style: AppTheme.monoStyle(scheme).copyWith(fontSize: 11, color: scheme.onSurfaceVariant)),
          if (keys.isNotEmpty) ...[const SizedBox(height: AppSpacing.s), for (final k in keys) _kvRow(context, k, attributes[k])],
        ],
      ),
    );
  }

  Widget _kvRow(BuildContext context, String key, Object? value) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(key, style: AppTheme.monoStyle(scheme).copyWith(fontSize: 11, color: scheme.onSurfaceVariant)),
          ),
          const SizedBox(width: AppSpacing.s),
          Expanded(child: Text('$value', style: AppTheme.monoStyle(scheme).copyWith(fontSize: 11))),
        ],
      ),
    );
  }

  Widget _sparklineCard(BuildContext context, Plug plug) {
    final scheme = Theme.of(context).colorScheme;
    final values = plug.history;
    final max = values.isEmpty ? 0.0 : values.reduce((a, b) => a > b ? a : b);
    final avg = values.isEmpty ? 0.0 : values.reduce((a, b) => a + b) / values.length;
    final last = values.isEmpty ? 0.0 : values.last;

    return Container(
      decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(AppRadii.card)),
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
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          last.toStringAsFixed(1),
                          style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 22, height: 1, color: scheme.onSurface),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'W now',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('peak ${max.toStringAsFixed(1)} W', style: AppTheme.monoStyle(scheme).copyWith(fontSize: 11)),
                  Text('avg ${avg.toStringAsFixed(1)} W', style: AppTheme.monoStyle(scheme).copyWith(fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
          SizedBox(height: 100, child: DetailSparkline(values: values)),
          const SizedBox(height: 4),
          DefaultTextStyle(
            style: AppTheme.monoStyle(scheme).copyWith(fontSize: 10, color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [Text('−60m'), Text('−45m'), Text('−30m'), Text('−15m'), Text('now')],
            ),
          ),
        ],
      ),
    );
  }

  /// AI diagnosis card: structured status chip + natural-language explanation +
  /// the specific findings. Hidden entirely when not signed in (no demo noise).
  Widget _diagnosisCard(BuildContext context, WidgetRef ref, Plug plug) {
    final scheme = Theme.of(context).colorScheme;
    final async = ref.watch(plugDiagnosisProvider(plug.entityId));
    final dx = async.valueOrNull;
    if (dx == null && !async.isLoading) return const SizedBox.shrink();

    final loading = async.isLoading && dx == null;
    final severity = dx?.severity ?? 'ok';
    final color = _severityColor(scheme, severity);
    final attention = dx?.needsAttention ?? false;
    final detailFindings = (dx?.findings ?? const <Finding>[]).where((f) => !const {'healthy', 'idle', 'collecting'}.contains(f.code)).toList();

    return Container(
      decoration: BoxDecoration(
        color: attention ? color.withValues(alpha: 0.10) : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: attention ? Border.all(color: color.withValues(alpha: 0.4)) : null,
      ),
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(icon: AppIcons.insights, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                'DIAGNOSIS',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 0.8, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (loading)
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              else
                _statusChip(context, icon: _severityIcon(severity), label: dx!.statusLabel, color: color),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
          if (loading)
            Text('Analysing recent behaviour…', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant))
          else ...[
            Text(dx!.explanation, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
            if (detailFindings.isNotEmpty) ...[const SizedBox(height: AppSpacing.m), for (final f in detailFindings) _findingRow(context, f)],
            if (dx.applianceGuess.isNotEmpty && dx.confidence > 0) ...[
              const SizedBox(height: AppSpacing.s),
              Text(
                'Signature looks like: ${dx.applianceGuess} (${(dx.confidence * 100).toStringAsFixed(0)}%)',
                style: AppTheme.monoStyle(scheme).copyWith(fontSize: 11),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _findingRow(BuildContext context, Finding f) {
    final scheme = Theme.of(context).colorScheme;
    final color = _severityColor(scheme, f.severity);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Text(f.message, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurface, height: 1.45)),
          ),
        ],
      ),
    );
  }

  static Color _severityColor(ColorScheme scheme, String severity) {
    switch (severity) {
      case 'critical':
        return scheme.error;
      case 'warning':
        return const Color(0xFFB26A00); // amber-700, readable on light/dark
      case 'info':
        return scheme.primary;
      default:
        return AppStatus.success;
    }
  }

  static dynamic _severityIcon(String severity) {
    switch (severity) {
      case 'critical':
        return AppIcons.alert;
      case 'warning':
        return AppIcons.warn;
      case 'info':
        return AppIcons.help;
      default:
        return AppIcons.check;
    }
  }

  Widget _criticalCard(BuildContext context, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(color: scheme.errorContainer.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(AppRadii.card)),
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onErrorContainer, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hintCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(AppRadii.card)),
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(icon: AppIcons.help, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Text(
              'Name and icon mirror what you set in Plug Assistance. Edit the '
              'entity there and changes show up after a refresh.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
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
