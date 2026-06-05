import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/constants.dart';
import '../models/plug.dart';

/// Thin wrapper around [FlutterSecureStorage] for app settings persistence.
/// Centralizes key names and serialization for ThemeMode.
class SecureStorage {
  SecureStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  final FlutterSecureStorage _storage;

  Future<AppSettings> load() async {
    final gatewayUrl =
        await _storage.read(key: AppConstants.storageKeyGatewayUrl);
    final accessToken =
        await _storage.read(key: AppConstants.storageKeyAccessToken);
    final refreshToken =
        await _storage.read(key: AppConstants.storageKeyRefreshToken);
    final email = await _storage.read(key: AppConstants.storageKeyEmail);
    final role = await _storage.read(key: AppConstants.storageKeyRole);
    final themeMode = _decodeTheme(
      await _storage.read(key: AppConstants.storageKeyThemeMode),
    );
    final pollStr = await _storage.read(key: AppConstants.storageKeyPollSeconds);
    final poll = int.tryParse(pollStr ?? '') ?? AppConstants.pollSeconds;
    return AppSettings(
      gatewayUrl: gatewayUrl,
      accessToken: accessToken,
      refreshToken: refreshToken,
      email: email,
      role: role,
      themeMode: themeMode,
      pollSeconds: poll,
    );
  }

  Future<void> save(AppSettings settings) async {
    await _writeOrDelete(
      AppConstants.storageKeyGatewayUrl,
      settings.gatewayUrl,
    );
    await _writeOrDelete(
      AppConstants.storageKeyAccessToken,
      settings.accessToken,
    );
    await _writeOrDelete(
      AppConstants.storageKeyRefreshToken,
      settings.refreshToken,
    );
    await _writeOrDelete(AppConstants.storageKeyEmail, settings.email);
    await _writeOrDelete(AppConstants.storageKeyRole, settings.role);
    await _storage.write(
      key: AppConstants.storageKeyThemeMode,
      value: _encodeTheme(settings.themeMode),
    );
    await _storage.write(
      key: AppConstants.storageKeyPollSeconds,
      value: settings.pollSeconds.toString(),
    );
  }

  Future<void> _writeOrDelete(String key, String? value) async {
    if (value == null) {
      await _storage.delete(key: key);
    } else {
      await _storage.write(key: key, value: value);
    }
  }

  /// Logs out: wipes the session (gateway, tokens, identity). Keeps ThemeMode
  /// + poll preference.
  Future<void> forgetInstance() async {
    await _storage.delete(key: AppConstants.storageKeyGatewayUrl);
    await _storage.delete(key: AppConstants.storageKeyAccessToken);
    await _storage.delete(key: AppConstants.storageKeyRefreshToken);
    await _storage.delete(key: AppConstants.storageKeyEmail);
    await _storage.delete(key: AppConstants.storageKeyRole);
  }

  String _encodeTheme(ThemeMode m) => switch (m) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };

  ThemeMode _decodeTheme(String? s) => switch (s) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
}
