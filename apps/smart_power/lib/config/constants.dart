/// App-wide constants.
///
/// Single place to tweak environment defaults. Per Handoff R3, these are
/// referenced from widgets — do not hardcode their values elsewhere.
class AppConstants {
  AppConstants._();

  /// Default Plug Assistance gateway URL prefilled on the login screen.
  /// The gateway holds the Home Assistant token server-side — the app never
  /// sees it; users authenticate here and receive a per-user token.
  ///
  /// TEMP (dev): points at the gateway running on the developer Mac. On the iOS
  /// Simulator, 127.0.0.1 is the Mac itself. The gateway then reaches the Pi
  /// over Tailscale server-side. For production, run the gateway on the Pi and
  /// set this to `http://100.83.45.15:8099`.
  /// Defaults to the public production gateway (Cloudflare Tunnel → Pi). Works
  /// from anywhere over HTTPS, no VPN. Override at build/run time if needed:
  ///   flutter run --dart-define=GATEWAY_URL=http://127.0.0.1:8099        (local dev)
  ///   flutter build appbundle --dart-define=GATEWAY_URL=https://gateway.danfordchris.dev
  static const String gatewayDefaultUrl = String.fromEnvironment('GATEWAY_URL', defaultValue: 'https://gateway.danfordchris.dev');

  /// Local-dev gateway hint (e.g. iOS Simulator) shown on the login screen.
  static const String gatewayLanUrl = 'http://127.0.0.1:8099';

  /// Polling cadence for plug state refresh when WebSocket is unused.
  /// Handoff §6 — Timer.periodic(Duration(seconds: 10)).
  static const int pollSeconds = 10;

  /// Network request timeout (Handoff §4.1).
  static const Duration httpTimeout = Duration(seconds: 5);

  /// Electricity tariff used for EVERY cost estimate shown in the app.
  /// 1 kWh == [tariffPerKwh] [currencySymbol]. Change these two values to
  /// re-price the whole app — no other file hardcodes a rate or currency.
  static const double tariffPerKwh = 500; // Tanzanian Shillings per kWh
  static const String currencySymbol = 'TSh';

  // ─── Bill / "View report" PDF ──────────────────────────────────────────
  // Issuer details printed on the generated electricity-bill PDF.
  static const String billCompanyName = 'Smart Power Technologies Ltd';
  static const List<String> billCompanyAddressLines = ['407 Nganana, 24311 Kikwe, Arumeru', 'P.O. BOX 475, Arusha'];
  static const String billCompanyEmail = 'dg@spt.co.tz';
  static const String billCompanyPhone = '0764971665';
  static const String billServiceAddress = '29 Salia Street, Dar es Salaam, Tanzania';

  /// Fixed monthly service charge added to every bill.
  static const double billServiceCharge = 5000;

  /// VAT applied to (energy + service) charges.
  static const double billVatRate = 0.18; // 18%

  /// Prefix for generated receipt / transaction references.
  static const String billReceiptPrefix = 'SPT';

  /// Secure storage keys.
  static const String storageKeyGatewayUrl = 'gateway_url';
  static const String storageKeyAccessToken = 'access_token';
  static const String storageKeyRefreshToken = 'refresh_token';
  static const String storageKeyEmail = 'user_email';
  static const String storageKeyRole = 'user_role';
  static const String storageKeyThemeMode = 'theme_mode';
  static const String storageKeyPollSeconds = 'poll_seconds';
}
