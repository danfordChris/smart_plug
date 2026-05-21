import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../config/app_icons.dart';
import '../config/theme.dart';
import '../providers/plugs_provider.dart';
import '../widgets/plug_card.dart';
import 'detail_screen.dart';

/// Devices — mirrors `DevicesScreen` in
/// `implementation_plan/mobile_design_docs/screens.jsx` (lines 943-974).
///
/// AppBar "Devices" · "X of Y on · synced from Home Assistant" subtitle ·
/// plug cards · "use the + tab" footer card.
class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(plugsProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Devices'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.read(plugsProvider.notifier).refresh(),
            icon: HugeIcon(
              icon: AppIcons.refresh,
              size: 22,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(plugsProvider.notifier).refresh(),
        child: async.when(
          data: (plugs) {
            if (plugs.isEmpty) return const _EmptyState();
            final onCount = plugs.where((p) => p.isOn).length;
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.l,
                0,
                AppSpacing.l,
                AppSpacing.xxl,
              ),
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                  child: Text(
                    '$onCount of ${plugs.length} on · synced from Home Assistant',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                for (final p in plugs) ...[
                  PlugCard(
                    plug: p,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DetailScreen(plugId: p.id),
                      ),
                    ),
                    onToggle: (_) async {
                      final ok =
                          await ref.read(plugsProvider.notifier).toggle(p.id);
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Couldn't reach Home Assistant"),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: AppSpacing.l),
                _addHint(context, scheme),
              ],
            );
          },
          loading: () => Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              children: const [
                PlugCardSkeleton(),
                SizedBox(height: 10),
                PlugCardSkeleton(),
              ],
            ),
          ),
          error: (_, __) => const _EmptyState(),
        ),
      ),
    );
  }

  Widget _addHint(BuildContext context, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Center(
        child: Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Need to add another plug? Use the '),
              TextSpan(
                text: '+',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
              const TextSpan(text: ' tab below.'),
            ],
          ),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      children: [
        const SizedBox(height: 80),
        Center(
          child: HugeIcon(
            icon: AppIcons.otherPlug,
            size: 64,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.l),
        Text(
          'No devices yet',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.s),
        Text(
          'Tap + in the bottom bar to add a SonOFF device via eWeLink.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
