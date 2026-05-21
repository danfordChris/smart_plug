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
    final url = await _storage.read(key: AppConstants.storageKeyUrl);
    final token = await _storage.read(key: AppConstants.storageKeyToken);
    final themeMode = _decodeTheme(
      await _storage.read(key: AppConstants.storageKeyThemeMode),
    );
    final pollStr = await _storage.read(key: AppConstants.storageKeyPollSeconds);
    final poll = int.tryParse(pollStr ?? '') ?? AppConstants.pollSeconds;
    return AppSettings(
      haUrl: url,
      haToken: token,
      themeMode: themeMode,
      pollSeconds: poll,
    );
  }

  Future<void> save(AppSettings settings) async {
    if (settings.haUrl != null) {
      await _storage.write(
        key: AppConstants.storageKeyUrl,
        value: settings.haUrl,
      );
    }
    if (settings.haToken != null) {
      await _storage.write(
        key: AppConstants.storageKeyToken,
        value: settings.haToken,
      );
    }
    await _storage.write(
      key: AppConstants.storageKeyThemeMode,
      value: _encodeTheme(settings.themeMode),
    );
    await _storage.write(
      key: AppConstants.storageKeyPollSeconds,
      value: settings.pollSeconds.toString(),
    );
  }

  /// Wipes URL + token. Keeps ThemeMode + poll preference.
  Future<void> forgetInstance() async {
    await _storage.delete(key: AppConstants.storageKeyUrl);
    await _storage.delete(key: AppConstants.storageKeyToken);
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
