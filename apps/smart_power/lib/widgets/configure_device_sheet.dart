import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../config/app_icons.dart';
import '../config/theme.dart';
import '../models/plug.dart';
import '../providers/plugs_provider.dart';

/// Bottom sheet to adopt/configure a plug: rename it and pick its appliance
/// type. Persists to Plug Assistance (entity registry + input_text helper).
///
/// Scope per operator decision (2026-05-21): "Adopt + rename/type only".
/// Pairing still happens in eWeLink; this configures an already-discovered
/// plug.
class ConfigureDeviceSheet extends ConsumerStatefulWidget {
  final Plug plug;
  const ConfigureDeviceSheet({super.key, required this.plug});

  static Future<void> show(BuildContext context, Plug plug) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
      ),
      builder: (_) => ConfigureDeviceSheet(plug: plug),
    );
  }

  @override
  ConsumerState<ConfigureDeviceSheet> createState() =>
      _ConfigureDeviceSheetState();
}

class _ConfigureDeviceSheetState extends ConsumerState<ConfigureDeviceSheet> {
  late final TextEditingController _nameCtrl;
  late ApplianceType _type;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.plug.name);
    _type = widget.plug.type;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await ref.read(plugsProvider.notifier).configureDevice(
          widget.plug.id,
          newName: _nameCtrl.text,
          newType: _type,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Saved to Plug Assistance'
            : "Couldn't save — connect to Plug Assistance and retry"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.l,
            AppSpacing.xxl,
            AppSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.l),
              Text(
                'Configure device',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 22,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.plug.entityId,
                style: AppTheme.monoStyle(scheme),
              ),
              const SizedBox(height: AppSpacing.l),

              // Name field
              TextField(
                controller: _nameCtrl,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Name',
                  helperText: 'Saved to Plug Assistance (entity registry).',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: scheme.surfaceContainerLow,
                ),
              ),
              const SizedBox(height: AppSpacing.l),

              // Appliance type picker
              Text(
                'Appliance type',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 15,
                    ),
              ),
              const SizedBox(height: AppSpacing.s),
              _typeGrid(scheme),
              if (_type.isCriticalLoad) ...[
                const SizedBox(height: AppSpacing.m),
                _criticalNote(scheme),
              ],
              const SizedBox(height: AppSpacing.xl),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.button),
                    ),
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeGrid(ColorScheme scheme) {
    return Wrap(
      spacing: AppSpacing.s,
      runSpacing: AppSpacing.s,
      children: [
        for (final t in ApplianceType.values) _typeChip(t, scheme),
      ],
    );
  }

  Widget _typeChip(ApplianceType t, ColorScheme scheme) {
    final selected = t == _type;
    return GestureDetector(
      onTap: () => setState(() => _type = t),
      child: AnimatedContainer(
        duration: AppMotion.cardGlyph,
        curve: AppMotion.emphasized,
        width: 84,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primaryContainer
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            HugeIcon(
              icon: _glyphFor(t),
              size: 24,
              color: selected
                  ? scheme.onPrimaryContainer
                  : scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 6),
            Text(
              t.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _criticalNote(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(icon: AppIcons.warn, size: 18, color: scheme.error),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Text(
              'Critical load — this device will be excluded from idle '
              'auto-off automations.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onErrorContainer,
                    height: 1.4,
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
