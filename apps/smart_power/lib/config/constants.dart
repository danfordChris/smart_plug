/// App-wide constants.
///
/// Single place to tweak environment defaults. Per Handoff R3, these are
/// referenced from widgets — do not hardcode their values elsewhere.
class AppConstants {
  AppConstants._();

  /// Default Home Assistant URL prefilled on the Setup screen.
  /// Resolves to the operator's Tailscale VPN address.
  static const String haDefaultUrl = 'http://100.83.45.15:8123';

  /// Fallback LAN URL — shown as a hint in the Setup field.
  static const String haLanUrl = 'http://192.168.1.19:8123';

  /// Polling cadence for plug state refresh when WebSocket is unused.
  /// Handoff §6 — Timer.periodic(Duration(seconds: 10)).
  static const int pollSeconds = 10;

  /// Network request timeout (Handoff §4.1).
  static const Duration httpTimeout = Duration(seconds: 5);

  /// Secure storage keys.
  static const String storageKeyUrl = 'ha_url';
  static const String storageKeyToken = 'ha_token';
  static const String storageKeyThemeMode = 'theme_mode';
  static const String storageKeyPollSeconds = 'poll_seconds';
}
