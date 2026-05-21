import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/plug.dart';
import '../services/storage.dart';

final secureStorageProvider = Provider<SecureStorage>((_) => SecureStorage());

/// Persistent app settings — HA URL, token, theme mode, poll interval.
/// Loaded from secure storage on app start.
class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final storage = ref.read(secureStorageProvider);
    return storage.load();
  }

  Future<void> saveCredentials({
    required String url,
    required String token,
  }) async {
    final storage = ref.read(secureStorageProvider);
    final current = state.valueOrNull ?? const AppSettings();
    final next = current.copyWith(haUrl: url, haToken: token);
    await storage.save(next);
    state = AsyncData(next);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final storage = ref.read(secureStorageProvider);
    final current = state.valueOrNull ?? const AppSettings();
    final next = current.copyWith(themeMode: mode);
    await storage.save(next);
    state = AsyncData(next);
  }

  Future<void> setPollSeconds(int seconds) async {
    final storage = ref.read(secureStorageProvider);
    final current = state.valueOrNull ?? const AppSettings();
    final next = current.copyWith(pollSeconds: seconds);
    await storage.save(next);
    state = AsyncData(next);
  }

  /// Wipes URL + token and routes the user back to Setup.
  Future<void> forgetInstance() async {
    final storage = ref.read(secureStorageProvider);
    await storage.forgetInstance();
    final current = state.valueOrNull ?? const AppSettings();
    state = AsyncData(current.copyWith(clear: true));
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
