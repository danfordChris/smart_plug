import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../config/app_icons.dart';
import '../config/theme.dart';
import '../providers/plugs_provider.dart';
import '../providers/settings_provider.dart';

/// Settings / Profile — mirrors `SettingsScreen` in
/// `implementation_plan/mobile_design_docs/screens.jsx` (lines 668-767).
///
/// Sections: Connection (HA url + masked token) · Refresh (poll slider with
/// 5s/30s/60s ticks) · Appearance (theme override) · About (version) ·
/// "Forget instance & sign out" outlined error button.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsProvider).valueOrNull;
    final plugs = ref.watch(plugsProvider).valueOrNull ?? const [];
    final url = settings?.haUrl ?? 'http://100.83.45.15:8123';
    final pollSeconds = settings?.pollSeconds ?? 10;
    final tokenTail = _tokenTail(settings?.haToken);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, AppSpacing.xxl),
        children: [
          // ── Connection ───────────────────────────────────────────
          _SectionHeader('Connection'),
          _Card(
            children: [
              _SettingsRow(
                icon: AppIcons.link,
                title: 'Home Assistant',
                subtitle: url,
                subtitleMono: true,
                trailing: _GreenDot(),
              ),
              _divider(scheme),
              _SettingsRow(
                icon: AppIcons.key,
                title: 'Access token',
                subtitle: '•••• •••• •••• $tokenTail',
                subtitleMono: true,
              ),
              _divider(scheme),
              _SettingsRow(
                icon: AppIcons.devices,
                title: 'Plug entities',
                subtitle: '${plugs.length} synced',
              ),
            ],
          ),

          // ── Refresh ──────────────────────────────────────────────
          _SectionHeader('Refresh'),
          _Card(
            children: [_PollSlider(seconds: pollSeconds)],
          ),

          // ── Appearance ───────────────────────────────────────────
          _SectionHeader('Appearance'),
          _Card(
            children: [
              Padding(
                padding: const EdgeInsets.all(4),
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Light'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Dark'),
                    ),
                  ],
                  selected: {settings?.themeMode ?? ThemeMode.system},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => ref
                      .read(settingsProvider.notifier)
                      .setThemeMode(s.first),
                ),
              ),
            ],
          ),

          // ── About ────────────────────────────────────────────────
          _SectionHeader('About'),
          _Card(
            children: [
              _SettingsRow(
                icon: AppIcons.bolt,
                title: 'Smart Power',
                subtitle: 'v0.1.0 · Flutter 3.35',
              ),
            ],
          ),

          // ── Forget ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: BorderSide(color: scheme.error),
                foregroundColor: scheme.error,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.button),
                ),
              ),
              onPressed: () => _confirmForget(context, ref),
              child: const Text('Forget instance & sign out'),
            ),
          ),
        ],
      ),
    );
  }

  static String _tokenTail(String? token) {
    if (token == null || token.length < 4) return '8f3a';
    return token.substring(token.length - 4);
  }

  Widget _divider(ColorScheme scheme) => Divider(
        height: 1,
        thickness: 0.5,
        indent: 52,
        color: scheme.outlineVariant,
      );

  Future<void> _confirmForget(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Forget this instance?'),
        content: const Text(
          "You'll need to paste the URL and a fresh long-lived token again to reconnect.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Forget'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(settingsProvider.notifier).forgetInstance();
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
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
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final dynamic icon;
  final String title;
  final String subtitle;
  final bool subtitleMono;
  final Widget? trailing;

  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.subtitleMono = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          HugeIcon(icon: icon, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: subtitleMono
                      ? AppTheme.monoStyle(scheme)
                      : Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _GreenDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: AppStatus.success,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _PollSlider extends ConsumerWidget {
  final int seconds;
  const _PollSlider({required this.seconds});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Poll every $seconds s',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            "Falls back to polling when WebSocket isn't available.",
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          Slider(
            value: seconds.toDouble().clamp(5, 60),
            min: 5,
            max: 60,
            divisions: 11,
            label: '$seconds s',
            onChanged: (v) => ref
                .read(settingsProvider.notifier)
                .setPollSeconds(v.round()),
          ),
          DefaultTextStyle(
            style: AppTheme.monoStyle(scheme).copyWith(fontSize: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('5s'),
                Text('30s'),
                Text('60s'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
