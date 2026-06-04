import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';
import 'home_scaffold.dart';
import 'setup_screen.dart';

/// When true, the app shows the dashboard with seeded demo data even though
/// no Plug Assistance instance is configured. Toggled by the "Preview with
/// demo data" button on the Setup screen — useful for design review.
final previewModeProvider = StateProvider<bool>((_) => false);

/// Chooses Setup vs HomeScaffold based on stored credentials (or preview mode).
class RootGate extends ConsumerWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final preview = ref.watch(previewModeProvider);
    return settings.when(
      data: (s) => (s.isConfigured || preview)
          ? const HomeScaffold()
          : const SetupScreen(),
      loading: () => const _LoadingScreen(),
      error: (_, __) => const SetupScreen(),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
