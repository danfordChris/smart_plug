import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/theme.dart';
import 'firebase_options.dart';
import 'providers/settings_provider.dart';
import 'screens/root_gate.dart';
import 'services/notifications.dart';
import 'services/push.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Local channel for foreground/alert presentation.
  await LocalNotifications.init();
  // Firebase Cloud Messaging for closed-app push. Best-effort: if Firebase
  // isn't available on this platform/build, the app still runs (in-app alerts
  // + local notifications continue to work).
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await PushService.init();
  } catch (_) {
    // Push disabled — non-fatal.
  }
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
