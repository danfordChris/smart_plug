/// App-wide constants.
///
/// Single place to tweak environment defaults. Per Handoff R3, these are
/// referenced from widgets — do not hardcode their values elsewhere.
class AppConstants {
  AppConstants._();

  /// Default Plug Assistance URL prefilled on the Setup screen.
  /// Resolves to the operator's Tailscale VPN address.
  static const String haDefaultUrl = 'http://100.83.45.15:8123';

  /// Fallback LAN URL — shown as a hint in the Setup field.
  static const String haLanUrl = 'http://192.168.1.19:8123';

  /// Default long-lived access token, prefilled on the Setup screen so the
  /// operator doesn't have to copy/paste it during development.
  ///
  /// TODO(security): remove before shipping — a baked-in token is a dev-only
  /// convenience. Rotate this token in Plug Assistance once no longer needed.
  static const String haDefaultToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiI3OWI4OWNlZjZhNGI0OWYxOTRlOTFjZDQxZDg1M2ViMyIsImlhdCI6MTc3OTcyMjk4OSwiZXhwIjoyMDk1MDgyOTg5fQ.Sfcg_rIlX1Mkf6Ewn9S35F-toMn-o-i65WBeFxFcvy0';

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
