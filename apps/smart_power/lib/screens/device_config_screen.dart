import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../config/app_icons.dart';
import '../config/theme.dart';
import '../models/device_config.dart';
import '../models/plug.dart';
import '../models/schedule.dart';
import '../providers/device_config_provider.dart';
import '../providers/plugs_provider.dart';
import '../providers/schedule_provider.dart';
import '../utils/snackbars.dart';
import 'alerts_screen.dart';

/// Device Configuration — lets the user schedule on/off for a plug (executed
/// server-side by the gateway) plus surface upcoming configuration (rename,
/// type, idle auto-off, alerts). Opened from the detail-screen gear button.
class DeviceConfigScreen extends ConsumerWidget {
  final String entityId;
  final String plugName;

  const DeviceConfigScreen({
    super.key,
    required this.entityId,
    required this.plugName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final api = ref.watch(scheduleApiProvider);
    final schedulesAsync = ref.watch(schedulesForEntityProvider(entityId));

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          icon: HugeIcon(icon: AppIcons.arrowBack, size: 22, color: scheme.onSurface),
        ),
        title: const Text('Device configuration'),
      ),
      floatingActionButton: api == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openEditor(context, ref),
              icon: HugeIcon(icon: AppIcons.add, size: 20, color: scheme.onPrimary),
              label: const Text('Add schedule'),
            ),
      body: SafeArea(
        top: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(AppSpacing.l, AppSpacing.m, AppSpacing.l, AppSpacing.xxl),
          children: [
            _header(context),
            const SizedBox(height: AppSpacing.l),
            _sectionHeader(context, 'Schedules'),
            if (api == null)
              _notice(
                context,
                'Sign in to your Plug Assistance account to create schedules. '
                'Schedules run on the server, so they switch the plug even when '
                'your phone is off.',
              )
            else
              schedulesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => _notice(
                  context,
                  "Couldn't load schedules. Pull to retry.",
                  isError: true,
                ),
                data: (schedules) => _scheduleList(context, ref, schedules),
              ),
            const SizedBox(height: AppSpacing.l),
            ..._configSections(context, ref, api != null),
          ],
        ),
      ),
    );
  }

  // ── Identity / auto-off / alerts (real config) ──────────────────────────
  List<Widget> _configSections(BuildContext context, WidgetRef ref, bool authed) {
    if (!authed) return const [];
    final configAsync = ref.watch(deviceConfigForEntityProvider(entityId));
    final plugs = ref.watch(plugsProvider).valueOrNull ?? const <Plug>[];
    final plug = plugs
        .cast<Plug?>()
        .firstWhere((p) => p?.entityId == entityId, orElse: () => null);

    final cfg = configAsync.valueOrNull ?? DeviceConfig(entityId: entityId);
    // Effective appliance type: user override wins, else the plug's inferred type.
    final effectiveType = cfg.typeOverride ?? plug?.type ?? ApplianceType.other;
    final critical = effectiveType.isCriticalLoad;
    final powerEntityId = _powerEntityFor(plug);

    return [
      _sectionHeader(context, 'Identity'),
      _identityCard(context, ref, cfg, effectiveType),
      const SizedBox(height: AppSpacing.l),
      _sectionHeader(context, 'Automation'),
      _autoOffCard(context, ref, cfg, critical, powerEntityId),
      const SizedBox(height: AppSpacing.l),
      _sectionHeader(context, 'Alerts & notifications'),
      _alertsCard(context, ref, cfg),
    ];
  }

  String _powerEntityFor(Plug? plug) {
    if (plug == null) return '';
    for (final entry in plug.readings.entries) {
      final id = entry.key.toLowerCase();
      if (id.contains('power') || entry.value.unit == 'W') return entry.key;
    }
    return '';
  }

  Widget _identityCard(
      BuildContext context, WidgetRef ref, DeviceConfig cfg, ApplianceType type) {
    final scheme = Theme.of(context).colorScheme;
    final name = cfg.displayName.isNotEmpty ? cfg.displayName : plugName;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: HugeIcon(icon: AppIcons.wrench, size: 20, color: scheme.onSurfaceVariant),
        title: Text(name, style: Theme.of(context).textTheme.bodyMedium),
        subtitle: Text(
          'Type: ${type.label}'
          '${cfg.displayName.isEmpty ? ' · using gateway name' : ''}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        trailing: HugeIcon(icon: AppIcons.chevronRight, size: 18, color: scheme.onSurfaceVariant),
        onTap: () => _openIdentityEditor(context, ref, cfg, type),
      ),
    );
  }

  Future<void> _openIdentityEditor(
      BuildContext context, WidgetRef ref, DeviceConfig cfg, ApplianceType type) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.cardLarge)),
      ),
      builder: (_) => _IdentityEditor(
        entityId: entityId,
        fallbackName: plugName,
        initialName: cfg.displayName,
        initialType: type,
      ),
    );
    if (saved == true) _invalidateConfig(ref);
  }

  Widget _autoOffCard(BuildContext context, WidgetRef ref, DeviceConfig cfg,
      bool critical, String powerEntityId) {
    final scheme = Theme.of(context).colorScheme;
    if (critical) {
      return _noticeRow(
        context,
        AppIcons.warn,
        scheme.error,
        'Auto-off is disabled for critical loads (fridge / water heater) to '
        'prevent spoilage. Change the appliance type to enable it.',
      );
    }
    final noPower = powerEntityId.isEmpty;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        children: [
          SwitchListTile(
            secondary: HugeIcon(icon: AppIcons.leaf, size: 20, color: scheme.onSurfaceVariant),
            title: const Text('Auto-off when idle'),
            subtitle: Text(
              noPower
                  ? 'Needs a power sensor on this plug to detect idle.'
                  : 'Turn off after ${cfg.autoOffIdleMinutes} min below '
                      '${cfg.autoOffThresholdW.toStringAsFixed(0)} W.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            value: cfg.autoOffEnabled,
            onChanged: noPower
                ? null
                : (v) => _setAutoOff(context, ref, cfg, v, powerEntityId),
          ),
          if (cfg.autoOffEnabled && !noPower) ...[
            Divider(height: 1, thickness: 0.5, indent: 56, color: scheme.outlineVariant),
            ListTile(
              leading: HugeIcon(icon: AppIcons.schedule, size: 20, color: scheme.onSurfaceVariant),
              title: const Text('Idle rule'),
              subtitle: Text(
                '${cfg.autoOffIdleMinutes} min · ${cfg.autoOffThresholdW.toStringAsFixed(0)} W threshold',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              trailing: HugeIcon(icon: AppIcons.chevronRight, size: 18, color: scheme.onSurfaceVariant),
              onTap: () => _openIdleEditor(context, ref, cfg, powerEntityId),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _setAutoOff(BuildContext context, WidgetRef ref, DeviceConfig cfg,
      bool enabled, String powerEntityId) async {
    final api = ref.read(deviceConfigApiProvider);
    if (api == null) return;
    try {
      await api.update(
        entityId,
        autoOffEnabled: enabled,
        // Make sure the server knows which sensor to watch.
        powerEntityId: powerEntityId,
      );
      _invalidateConfig(ref);
    } catch (_) {
      if (context.mounted) AppSnack.info(context, "Couldn't update auto-off");
    }
  }

  Future<void> _openIdleEditor(BuildContext context, WidgetRef ref,
      DeviceConfig cfg, String powerEntityId) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.cardLarge)),
      ),
      builder: (_) => _IdleRuleEditor(
        entityId: entityId,
        powerEntityId: powerEntityId,
        initialMinutes: cfg.autoOffIdleMinutes,
        initialThreshold: cfg.autoOffThresholdW,
      ),
    );
    if (saved == true) _invalidateConfig(ref);
  }

  Widget _alertsCard(BuildContext context, WidgetRef ref, DeviceConfig cfg) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        children: [
          SwitchListTile(
            secondary: HugeIcon(icon: AppIcons.bell, size: 20, color: scheme.onSurfaceVariant),
            title: const Text('Alerts for this plug'),
            subtitle: Text(
              'Notify on offline/online, idle auto-off and schedule actions.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            value: cfg.alertsEnabled,
            onChanged: (v) => _setAlerts(context, ref, v),
          ),
          Divider(height: 1, thickness: 0.5, indent: 56, color: scheme.outlineVariant),
          ListTile(
            leading: HugeIcon(icon: AppIcons.insights, size: 20, color: scheme.onSurfaceVariant),
            title: const Text('View alerts'),
            trailing: HugeIcon(icon: AppIcons.chevronRight, size: 18, color: scheme.onSurfaceVariant),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AlertsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setAlerts(BuildContext context, WidgetRef ref, bool enabled) async {
    final api = ref.read(deviceConfigApiProvider);
    if (api == null) return;
    try {
      await api.update(entityId, alertsEnabled: enabled);
      _invalidateConfig(ref);
    } catch (_) {
      if (context.mounted) AppSnack.info(context, "Couldn't update alerts");
    }
  }

  void _invalidateConfig(WidgetRef ref) {
    ref.invalidate(deviceConfigForEntityProvider(entityId));
    ref.invalidate(deviceConfigsProvider);
    ref.invalidate(plugsProvider);
  }

  Widget _noticeRow(BuildContext context, dynamic icon, Color color, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(icon: icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Text(
              text,
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

  Widget _header(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Row(
        children: [
          HugeIcon(icon: AppIcons.schedule, size: 22, color: scheme.primary),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plugName, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  entityId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.monoStyle(scheme).copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scheduleList(BuildContext context, WidgetRef ref, List<Schedule> schedules) {
    if (schedules.isEmpty) {
      return _notice(
        context,
        'No schedules yet. Tap "Add schedule" to turn this plug on or off '
        'automatically at a set time.',
      );
    }
    return Column(
      children: [
        for (final s in schedules) ...[
          _scheduleTile(context, ref, s),
          const SizedBox(height: AppSpacing.s),
        ],
      ],
    );
  }

  Widget _scheduleTile(BuildContext context, WidgetRef ref, Schedule s) {
    final scheme = Theme.of(context).colorScheme;
    final on = s.isOn;
    final accent = on ? AppStatus.success : scheme.error;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      padding: const EdgeInsets.fromLTRB(AppSpacing.m, AppSpacing.s, AppSpacing.s, AppSpacing.s),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.button),
            ),
            child: Center(
              child: HugeIcon(
                icon: on ? AppIcons.power : AppIcons.close,
                size: 20,
                color: accent,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      s.timeHhmm,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Turn ${on ? 'on' : 'off'}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: accent),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  s.label.isNotEmpty ? '${s.label} · ${s.recurrenceLabel}' : s.recurrenceLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Switch(
            value: s.enabled,
            onChanged: (v) => _toggle(context, ref, s, v),
          ),
          IconButton(
            tooltip: 'Edit',
            onPressed: () => _openEditor(context, ref, existing: s),
            icon: HugeIcon(icon: AppIcons.settings, size: 18, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, Schedule s, bool enabled) async {
    final api = ref.read(scheduleApiProvider);
    if (api == null) return;
    try {
      await api.update(s.id, enabled: enabled);
      ref.invalidate(schedulesForEntityProvider(entityId));
    } catch (_) {
      if (context.mounted) AppSnack.info(context, "Couldn't update the schedule");
    }
  }

  Future<void> _openEditor(BuildContext context, WidgetRef ref, {Schedule? existing}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.cardLarge)),
      ),
      builder: (_) => _ScheduleEditor(entityId: entityId, existing: existing),
    );
    if (result == true) {
      ref.invalidate(schedulesForEntityProvider(entityId));
    }
  }

  // ── Reusable bits ───────────────────────────────────────────────────────
  Widget _sectionHeader(BuildContext context, String title) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, AppSpacing.s),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.primary,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _notice(BuildContext context, String text, {bool isError = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(
            icon: isError ? AppIcons.alert : AppIcons.help,
            size: 18,
            color: isError ? scheme.error : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Text(
              text,
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

}

/// Add / edit a schedule. Returns `true` via Navigator.pop on a successful save.
class _ScheduleEditor extends ConsumerStatefulWidget {
  final String entityId;
  final Schedule? existing;
  const _ScheduleEditor({required this.entityId, this.existing});

  @override
  ConsumerState<_ScheduleEditor> createState() => _ScheduleEditorState();
}

class _ScheduleEditorState extends ConsumerState<_ScheduleEditor> {
  late bool _turnOn;
  late TimeOfDay _time;
  late Set<int> _days; // empty = every day
  late TextEditingController _label;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _turnOn = e?.isOn ?? true;
    _time = _parseTime(e?.timeHhmm ?? '06:00');
    _days = {...?e?.dayInts};
    _label = TextEditingController(text: e?.label ?? '');
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  static TimeOfDay _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 6,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
  }

  String get _timeHhmm =>
      '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    final api = ref.read(scheduleApiProvider);
    if (api == null) return;
    setState(() => _saving = true);
    final days = (_days.toList()..sort()).join(',');
    try {
      if (widget.existing == null) {
        await api.create(
          entityId: widget.entityId,
          action: _turnOn ? 'on' : 'off',
          timeHhmm: _timeHhmm,
          days: days,
          label: _label.text.trim(),
        );
      } else {
        await api.update(
          widget.existing!.id,
          action: _turnOn ? 'on' : 'off',
          timeHhmm: _timeHhmm,
          days: days,
          label: _label.text.trim(),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnack.info(context, "Couldn't save the schedule");
      }
    }
  }

  Future<void> _delete() async {
    final api = ref.read(scheduleApiProvider);
    final existing = widget.existing;
    if (api == null || existing == null) return;
    setState(() => _saving = true);
    try {
      await api.delete(existing.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnack.info(context, "Couldn't delete the schedule");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isEdit = widget.existing != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.l, AppSpacing.m, AppSpacing.l, AppSpacing.l + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.l),
              decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(99)),
            ),
          ),
          Text(
            isEdit ? 'Edit schedule' : 'New schedule',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.l),

          // Action segmented control.
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Turn on'), icon: Icon(Icons.power_settings_new)),
              ButtonSegment(value: false, label: Text('Turn off'), icon: Icon(Icons.power_off)),
            ],
            selected: {_turnOn},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _turnOn = s.first),
          ),
          const SizedBox(height: AppSpacing.l),

          // Time picker row.
          InkWell(
            borderRadius: BorderRadius.circular(AppRadii.card),
            onTap: () async {
              final picked = await showTimePicker(context: context, initialTime: _time);
              if (picked != null) setState(() => _time = picked);
            },
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadii.card),
              ),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: AppSpacing.l),
              child: Row(
                children: [
                  HugeIcon(icon: AppIcons.schedule, size: 20, color: scheme.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.m),
                  Text('Time', style: Theme.of(context).textTheme.bodyLarge),
                  const Spacer(),
                  Text(
                    _time.format(context),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.l),

          Text('Repeat', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.s),
          Wrap(
            spacing: 6,
            children: [
              for (var i = 0; i < 7; i++)
                FilterChip(
                  label: Text(Schedule.weekdayShort[i]),
                  selected: _days.contains(i),
                  onSelected: (sel) => setState(() {
                    if (sel) {
                      _days.add(i);
                    } else {
                      _days.remove(i);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            Schedule.describeDays(_days),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.l),

          TextField(
            controller: _label,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Label (optional)',
              hintText: 'e.g. Morning warm-up',
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(isEdit ? 'Save changes' : 'Create schedule'),
          ),
          if (isEdit) ...[
            const SizedBox(height: AppSpacing.s),
            TextButton(
              onPressed: _saving ? null : _delete,
              style: TextButton.styleFrom(foregroundColor: scheme.error),
              child: const Text('Delete schedule'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Rename + appliance type editor. Pops `true` on a successful save.
class _IdentityEditor extends ConsumerStatefulWidget {
  final String entityId;
  final String fallbackName;
  final String initialName;
  final ApplianceType initialType;
  const _IdentityEditor({
    required this.entityId,
    required this.fallbackName,
    required this.initialName,
    required this.initialType,
  });

  @override
  ConsumerState<_IdentityEditor> createState() => _IdentityEditorState();
}

class _IdentityEditorState extends ConsumerState<_IdentityEditor> {
  late TextEditingController _name;
  late ApplianceType _type;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName);
    _type = widget.initialType;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final api = ref.read(deviceConfigApiProvider);
    if (api == null) return;
    setState(() => _saving = true);
    try {
      await api.update(
        widget.entityId,
        displayName: _name.text.trim(),
        applianceType: applianceTypeName(_type),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnack.info(context, "Couldn't save");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.l, AppSpacing.m, AppSpacing.l, AppSpacing.l + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.l),
              decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(99)),
            ),
          ),
          Text('Rename & icon', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.l),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Display name',
              hintText: widget.fallbackName,
              helperText: 'Leave blank to use the gateway name.',
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          DropdownButtonFormField<ApplianceType>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Appliance type'),
            items: [
              for (final t in ApplianceType.values)
                DropdownMenuItem(value: t, child: Text(t.label)),
            ],
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
          if (_type.isCriticalLoad) ...[
            const SizedBox(height: AppSpacing.s),
            Text(
              'Critical load — idle auto-off stays disabled to protect it.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}

/// Idle auto-off rule editor (minutes + watt threshold). Pops `true` on save.
class _IdleRuleEditor extends ConsumerStatefulWidget {
  final String entityId;
  final String powerEntityId;
  final int initialMinutes;
  final double initialThreshold;
  const _IdleRuleEditor({
    required this.entityId,
    required this.powerEntityId,
    required this.initialMinutes,
    required this.initialThreshold,
  });

  @override
  ConsumerState<_IdleRuleEditor> createState() => _IdleRuleEditorState();
}

class _IdleRuleEditorState extends ConsumerState<_IdleRuleEditor> {
  late double _minutes;
  late double _threshold;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _minutes = widget.initialMinutes.toDouble().clamp(1, 180);
    _threshold = widget.initialThreshold.clamp(0, 100);
  }

  Future<void> _save() async {
    final api = ref.read(deviceConfigApiProvider);
    if (api == null) return;
    setState(() => _saving = true);
    try {
      await api.update(
        widget.entityId,
        autoOffIdleMinutes: _minutes.round(),
        autoOffThresholdW: _threshold,
        powerEntityId: widget.powerEntityId,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnack.info(context, "Couldn't save");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.l, AppSpacing.m, AppSpacing.l, AppSpacing.l + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.l),
              decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(99)),
            ),
          ),
          Text('Idle auto-off rule', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.l),
          Text('Turn off after ${_minutes.round()} min idle',
              style: Theme.of(context).textTheme.bodyLarge),
          Slider(
            value: _minutes,
            min: 1,
            max: 180,
            divisions: 179,
            label: '${_minutes.round()} min',
            onChanged: (v) => setState(() => _minutes = v),
          ),
          const SizedBox(height: AppSpacing.s),
          Text('Idle threshold: ${_threshold.toStringAsFixed(0)} W',
              style: Theme.of(context).textTheme.bodyLarge),
          Text(
            'Considered idle when power stays below this.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          Slider(
            value: _threshold,
            min: 0,
            max: 100,
            divisions: 100,
            label: '${_threshold.toStringAsFixed(0)} W',
            onChanged: (v) => setState(() => _threshold = v),
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save rule'),
          ),
        ],
      ),
    );
  }
}
