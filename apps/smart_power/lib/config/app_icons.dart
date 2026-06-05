import 'package:hugeicons/hugeicons.dart';

/// Centralised semantic → HugeIcons mapping.
///
/// **Strict rule (operator requirement):** widgets MUST consume icons from
/// this file. Direct uses of `Icons.*` (Material) or any other icon set are
/// forbidden in feature code. Update this file when adding a new icon need.
///
/// Names mirror the prototype's icon variable names in
/// `implementation_plan/mobile_design_docs/icons.jsx` and
/// `dashboard-widgets.jsx`. Visual equivalents picked from the
/// `strokeRounded*` family — the JSX prototype uses 1.8 px stroke rounded
/// linecaps, which is what HugeIcons' strokeRounded set provides.
class AppIcons {
  AppIcons._();

  // ── Social / connect ─────────────────────────────────────────────
  static const instagram = HugeIcons.strokeRoundedInstagram;
  static const twitterX = HugeIcons.strokeRoundedNewTwitter;
  static const facebook = HugeIcons.strokeRoundedFacebook01;
  static const youtube = HugeIcons.strokeRoundedYoutube;
  static const whatsapp = HugeIcons.strokeRoundedWhatsapp;
  static const support = HugeIcons.strokeRoundedCustomerSupport;
  static const login = HugeIcons.strokeRoundedLogin03;
  static const register = HugeIcons.strokeRoundedUserAdd01;

  // ── Navigation / bottom-nav ──────────────────────────────────────
  static const home = HugeIcons.strokeRoundedHome05;
  static const devices = HugeIcons.strokeRoundedSmartPhone02;
  static const insights = HugeIcons.strokeRoundedAnalytics02;
  static const profile = HugeIcons.strokeRoundedUser;
  static const add = HugeIcons.strokeRoundedAdd01;

  // ── App bar / header actions ─────────────────────────────────────
  static const refresh = HugeIcons.strokeRoundedRefresh;
  static const bell = HugeIcons.strokeRoundedNotification02;
  static const settings = HugeIcons.strokeRoundedSettings02;
  static const arrowBack = HugeIcons.strokeRoundedArrowLeft01;
  static const chevronRight = HugeIcons.strokeRoundedArrowRight01;

  // ── Setup / status / connection ──────────────────────────────────
  static const bolt = HugeIcons.strokeRoundedFlash;
  static const wifi = HugeIcons.strokeRoundedWifi02;
  static const cloudOff = HugeIcons.strokeRoundedWifiDisconnected01;
  static const check = HugeIcons.strokeRoundedCheckmarkCircle02;
  static const alert = HugeIcons.strokeRoundedAlertCircle;
  static const eye = HugeIcons.strokeRoundedView;
  static const eyeOff = HugeIcons.strokeRoundedViewOff;
  static const key = HugeIcons.strokeRoundedSquareLock02;
  static const help = HugeIcons.strokeRoundedHelpCircle;
  static const link = HugeIcons.strokeRoundedLink04;
  static const close = HugeIcons.strokeRoundedCancel01;
  static const lock = HugeIcons.strokeRoundedLockPassword;

  // ── Quick access tiles (dashboard) ───────────────────────────────
  static const schedule = HugeIcons.strokeRoundedCalendar01;
  static const wrench = HugeIcons.strokeRoundedWrench01;
  static const warn = HugeIcons.strokeRoundedAlert02;
  static const leaf = HugeIcons.strokeRoundedLeaf01;

  // ── Stat tile icons ──────────────────────────────────────────────
  static const power = HugeIcons.strokeRoundedFlash;
  static const voltage = HugeIcons.strokeRoundedPowerSocket01;
  static const current = HugeIcons.strokeRoundedActivity01;
  static const energy = HugeIcons.strokeRoundedChart01;
  static const trend = HugeIcons.strokeRoundedChartIncrease;
  static const download = HugeIcons.strokeRoundedDownload04;
  static const document = HugeIcons.strokeRoundedInvoice01;

  // ── Inline arrows for delta pills ────────────────────────────────
  static const arrowUp = HugeIcons.strokeRoundedArrowUp01;
  static const arrowDown = HugeIcons.strokeRoundedArrowDown01;

  // ── Appliance glyphs ─────────────────────────────────────────────
  static const radio = HugeIcons.strokeRoundedRadio01;
  static const fridge = HugeIcons.strokeRoundedRefrigerator;
  static const heater = HugeIcons.strokeRoundedFire;
  static const airConditioner = HugeIcons.strokeRoundedSmartAc;
  static const washer = HugeIcons.strokeRoundedWashingMachine;
  static const waterHeater = HugeIcons.strokeRoundedHotTube;
  static const light = HugeIcons.strokeRoundedBulb;
  static const otherPlug = HugeIcons.strokeRoundedPlug01;
}
