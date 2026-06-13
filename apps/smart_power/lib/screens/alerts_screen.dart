import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../config/app_icons.dart';
import '../config/theme.dart';
import '../models/alert.dart';
import '../providers/alerts_provider.dart';
import '../utils/formatters.dart';
import '../utils/snackbars.dart';

/// In-app alerts feed: offline/online, idle auto-off, schedule fired.
class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final api = ref.watch(alertsApiProvider);
    final alertsAsync = ref.watch(alertsProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          icon: HugeIcon(icon: AppIcons.arrowBack, size: 22, color: scheme.onSurface),
        ),
        title: const Text('Alerts'),
        actions: [
          if (api != null)
            TextButton(
              onPressed: () async {
                await api.markAllRead();
                ref.invalidate(alertsProvider);
                ref.invalidate(unreadAlertsCountProvider);
              },
              child: const Text('Mark read'),
            ),
          if (api != null)
            IconButton(
              tooltip: 'Clear all',
              onPressed: () async {
                await api.clear();
                ref.invalidate(alertsProvider);
                ref.invalidate(unreadAlertsCountProvider);
                if (context.mounted) AppSnack.info(context, 'Alerts cleared');
              },
              icon: HugeIcon(icon: AppIcons.close, size: 20, color: scheme.onSurfaceVariant),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(alertsProvider),
        child: alertsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _empty(context, 'Couldn\'t load alerts.', isError: true),
          data: (alerts) {
            if (api == null) {
              return _empty(context, 'Sign in to see alerts.');
            }
            if (alerts.isEmpty) {
              return _empty(context, 'No alerts yet. Offline events, idle '
                  'auto-off, and schedule actions will show up here.');
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.all(AppSpacing.l),
              itemCount: alerts.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s),
              itemBuilder: (_, i) => _AlertTile(alert: alerts[i]),
            );
          },
        ),
      ),
    );
  }

  Widget _empty(BuildContext context, String text, {bool isError = false}) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      children: [
        const SizedBox(height: 120),
        Icon(isError ? Icons.error_outline : Icons.notifications_none,
            size: 48, color: scheme.onSurfaceVariant),
        const SizedBox(height: AppSpacing.m),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _AlertTile extends StatelessWidget {
  final AppAlert alert;
  const _AlertTile({required this.alert});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = _visualFor(alert.kind, scheme);
    return Container(
      decoration: BoxDecoration(
        color: alert.read ? scheme.surfaceContainerLow : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: alert.read ? null : Border.all(color: color.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.button),
            ),
            child: Center(child: HugeIcon(icon: icon, size: 18, color: color)),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.message, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 2),
                Text(
                  alert.createdAt == null ? '' : Fmt.relative(alert.createdAt),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (dynamic, Color) _visualFor(String kind, ColorScheme scheme) {
    switch (kind) {
      case 'offline':
        return (AppIcons.cloudOff, scheme.error);
      case 'online':
        return (AppIcons.wifi, AppStatus.success);
      case 'auto_off':
        return (AppIcons.leaf, AppStatus.success);
      case 'schedule_fired':
        return (AppIcons.schedule, scheme.primary);
      default:
        return (AppIcons.bell, scheme.onSurfaceVariant);
    }
  }
}
