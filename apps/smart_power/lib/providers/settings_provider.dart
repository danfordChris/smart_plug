import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/plug.dart';
import '../services/auth_api.dart';
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

  /// Persists a freshly authenticated session (login).
  Future<void> saveSession({
    required String gatewayUrl,
    required AuthSession session,
    required String email,
  }) async {
    final storage = ref.read(secureStorageProvider);
    final current = state.valueOrNull ?? const AppSettings();
    final next = current.copyWith(
      gatewayUrl: gatewayUrl,
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      role: session.role,
      email: email,
    );
    await storage.save(next);
    state = AsyncData(next);
  }

  /// Exchanges the stored refresh token for a new access token. Returns the
  /// new access token, or null if refresh failed (which also logs out).
  /// Used by the HaApi 401 interceptor.
  Future<String?> refreshAccessToken() async {
    final current = state.valueOrNull;
    final gatewayUrl = current?.gatewayUrl;
    final refreshToken = current?.refreshToken;
    if (gatewayUrl == null || refreshToken == null) return null;
    final api = AuthApi(baseUrl: gatewayUrl);
    try {
      final session = await api.refresh(refreshToken);
      final storage = ref.read(secureStorageProvider);
      final next = current!.copyWith(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        role: session.role,
      );
      await storage.save(next);
      state = AsyncData(next);
      return session.accessToken;
    } catch (_) {
      // Refresh failed (revoked/expired) → force a clean logout.
      await logout();
      return null;
    } finally {
      api.dispose();
    }
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

  /// Logs out: best-effort server-side revoke, then wipes the local session
  /// and routes the user back to the login screen.
  Future<void> logout() async {
    final current = state.valueOrNull;
    if (current?.gatewayUrl != null && current?.refreshToken != null) {
      final api = AuthApi(baseUrl: current!.gatewayUrl!);
      await api.logout(current.refreshToken!);
      api.dispose();
    }
    final storage = ref.read(secureStorageProvider);
    await storage.forgetInstance();
    state = AsyncData((current ?? const AppSettings()).copyWith(clear: true));
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
