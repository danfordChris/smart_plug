import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/theme.dart';
import 'providers/settings_provider.dart';
import 'screens/root_gate.dart';

void main() {
  runApp(const ProviderScope(child: SmartPowerApp()));
}

class SmartPowerApp extends ConsumerWidget {
  const SmartPowerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).valueOrNull;
    return MaterialApp(
      title: 'Smart Power',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings?.themeMode ?? ThemeMode.system,
      home: const RootGate(),
    );
  }
}
