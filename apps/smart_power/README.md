# Smart Power

Flutter mobile app for monitoring and controlling SonOFF smart plugs through Plug Assistance.

Strict 1:1 implementation of `implementation_plan/mobile_design_docs/` — design tokens,
widget mapping, per-screen specs, fl_chart configs, and acceptance criteria from
`Flutter Handoff.md` (Material 3, Outfit + DM Sans typography, forest-green seed
`#1F8A5B`).

This app talks directly to a self-hosted Plug Assistance instance over the local
network or Tailscale VPN. There is no cloud backend.

---

## Features

- **Setup screen** — paste HA URL + a long-lived access token, test connection, save.
- **Dashboard** — greeting header, energy hero card with 24-pt sparkline, quick-access
  pills, plug cards (live state + power), insight cards, connection footer.
- **Detail screen** — large hero icon, M3 switch panel (animated bg), 2×2 stat grid
  (power / voltage / current / today kWh), 60-pt sparkline of power history, hint card.
  Critical loads (fridge, water heater) get a safety banner.
- **Appliances** — list view of every plug for direct control.
- **Analytics** — weekly bar chart, top-appliance breakdown with progress bars,
  recommendations.
- **Profile / Settings** — connection summary, theme override (system/light/dark),
  poll cadence slider (5–60 s), "Forget instance" destructive action.
- **Add device sheet** — 4-step instructions for adding new SonOFFs via eWeLink.

---

## Requirements

- Flutter 3.35+ on the stable channel
- iOS 13+ / Android API 23+
- A Plug Assistance instance reachable on the same network or via Tailscale
- A long-lived access token from Plug Assistance

---

## Signing in (auth gateway)

The app no longer holds a Home Assistant token. It logs in to the **Plug Assistance
gateway** (`services/plug-gateway/`), which issues a per-user token and forwards requests to
Home Assistant using a token held server-side. Start that gateway first — see
`services/plug-gateway/README.md` → *Local development & testing*.

**Test account** (the first account created becomes an active admin):

| Field | Value |
|-------|-------|
| Email | `owner@home.test` |
| Password | `ownerpass123` |

On the login screen, set the **Gateway server** URL for your platform:

| App runs on | Gateway URL |
|-------------|-------------|
| iOS Simulator | `http://127.0.0.1:8099` |
| Android Emulator | `http://10.0.2.2:8099` |
| Physical device (Tailnet) | `http://<dev-machine-tailscale-ip>:8099` |

Then log in with the test account above. Keep **Tailscale up** on the dev machine so the
gateway can reach the Pi. (The gateway URL also has a prefilled default in
`lib/config/constants.dart`.)

---

## Running the app

```bash
cd apps/smart_power
flutter pub get
flutter run
```

Pick a device or emulator when prompted. For iOS:

```bash
flutter run -d ios
```

For Android:

```bash
flutter run -d android
```

The first launch shows the **login screen**. Log in with the test account above (or sign
up). The **Gateway server** URL is prefilled from `AppConstants.gatewayDefaultUrl` — adjust
it for your platform (see *Signing in* above). The gateway must be running.

---

## Building release artifacts

### Android (APK)

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### Android (App Bundle)

```bash
flutter build appbundle --release
```

### iOS

```bash
flutter build ios --release
```

Then open `ios/Runner.xcworkspace` in Xcode and archive.

---

## Configuration that drives the app

The defaults live in `lib/config/constants.dart`:

| Constant | Default | Notes |
|---|---|---|
| `haDefaultUrl` | `http://100.83.45.15:8123` | Prefilled on Setup screen |
| `haLanUrl` | `http://192.168.1.19:8123` | Documented as alternate |
| `pollSeconds` | `10` | Initial polling cadence; user-tunable in Settings |
| `httpTimeout` | `5 s` | Per Handoff §4.1 |

Secure storage keys are also defined here so they stay consistent across reads/writes.

---

## Project structure

```
lib/
├─ main.dart                     SmartPowerApp + RootGate wiring
├─ config/
│  ├─ constants.dart             Defaults, storage keys
│  └─ theme.dart                 AppColors, AppRadii, AppSpacing, AppMotion, AppTheme
├─ models/
│  ├─ plug.dart                  Plug, PlugState, ApplianceType, AppSettings
│  └─ ha_state.dart              Raw /api/states response shape
├─ services/
│  ├─ ha_api.dart                Dio client (testConnection, listStates, turnOn/Off)
│  └─ storage.dart               flutter_secure_storage wrapper
├─ providers/
│  ├─ settings_provider.dart     AsyncNotifier<AppSettings> + persistence
│  └─ plugs_provider.dart        AsyncNotifier<List<Plug>> + polling + optimistic toggle
├─ screens/
│  ├─ root_gate.dart             Routes to Setup or HomeScaffold
│  ├─ home_scaffold.dart         4 tabs + SmartBottomNav + Add Device sheet
│  ├─ setup_screen.dart          Connection setup (Handoff §4.1)
│  ├─ dashboard_screen.dart      Home tab (Handoff §4.2)
│  ├─ devices_screen.dart        Appliances tab — list-only variant
│  ├─ detail_screen.dart         Per-plug detail (Handoff §4.3)
│  ├─ insights_screen.dart       Analytics tab (Handoff §4.4)
│  └─ settings_screen.dart       Profile tab (Handoff §4.5)
├─ widgets/
│  ├─ smart_bottom_nav.dart      NavigationBar + center FAB
│  ├─ plug_card.dart             Dashboard list item
│  ├─ stat_tile.dart             2×2 detail grid tile
│  ├─ energy_hero_card.dart      Dashboard hero with sparkline
│  ├─ insight_card.dart          Reusable insight/alert row
│  ├─ quick_access_tile.dart     Horizontal pill
│  ├─ connection_banner.dart     "Disconnected" banner + StatusDot
│  └─ sparkline.dart             HeroSparkline + DetailSparkline + WeeklyBarChart
└─ utils/
   └─ formatters.dart            kWh / W / V / A / £ / "Xm ago"
```

---

## Architecture decisions

- **Material 3 only.** No Cupertino widgets. `Switch` (not `Switch.adaptive`).
  `NavigationBar` (not `BottomNavigationBar`).
- **No state library beyond Riverpod.** No bloc, no provider package, no GetX.
- **Direct REST.** No backend. Optimistic UI updates, 5-second HTTP timeout,
  revert + snackbar on failure.
- **Fonts via google_fonts** at runtime. For air-gapped builds, bundle Outfit +
  DM Sans + JetBrains Mono into `assets/fonts/`.
- **Tabular figures** on every auto-updating numeric. Prevents digit jitter.
- **Critical loads** (fridge, water heater) are flagged in the model. The Detail
  screen surfaces a banner so the operator never auto-offs them.
- **Add device flow** is intentionally a guide, not an in-app pairing — SonoffLAN
  auto-discovers new plugs added through eWeLink.

---

## Acceptance walkthrough (Handoff §10)

| # | Flow | Status |
|---|---|---|
| 1 | Cold start with no token → Setup screen | ✅ via RootGate |
| 2 | Bad token → Test fails red | ✅ via _humanError() in setup_screen |
| 3 | Good token → Save → Dashboard | ✅ via SettingsNotifier.saveCredentials |
| 4 | Toggle plug → animates instantly; reverts + snackbar on failure | ✅ PlugsNotifier.toggle |
| 5 | Pull-to-refresh updates readings | ✅ RefreshIndicator wired to refresh() |
| 6 | Tap card → Hero transition → Detail; big switch toggles | ✅ Hero(tag: 'plug-$id') |
| 7 | Insights tab → weekly chart with today highlighted | ✅ WeeklyBarChart todayIndex |
| 8 | Profile → Forget instance → returns to Setup | ✅ SettingsNotifier.forgetInstance |
| 9 | Toggle system dark mode → app re-themes without restart | ✅ themeMode: ThemeMode.system |
| 10 | Network down → red "Disconnected" banner with Retry | ✅ ConnectionBanner |

---

## Out of scope (per Handoff §11)

The app **does not** include:

- Multi-user accounts or cloud sync
- Push notifications (Plug Assistance Companion App or HA notifications handle that)
- Automation editing (use Plug Assistance's web UI)
- History older than the in-memory 60-point sparkline (use HA's Energy dashboard)
- In-app SonOFF pairing (use eWeLink — the app discovers automatically)

If the operator requests one of these, point them to Plug Assistance's web UI.

---

## Quality gates

- `flutter analyze` → 0 issues
- `flutter test` → 5/5 passing
- `flutter build apk --debug` → succeeds
- Both light and dark themes render correctly on every screen
- Setup → Dashboard → Detail → Setup loop works end-to-end

---

## Linked design sources

- `implementation_plan/mobile_design_docs/Flutter Handoff.md` — primary spec
- `implementation_plan/mobile_design_docs/Smart Plugs App.html` — HTML prototype
- `implementation_plan/mobile_design_docs/styles.css` — M3 design tokens
- `implementation_plan/mobile_design_docs/screens.jsx` — Setup/Dashboard/Detail behavior
- `implementation_plan/mobile_design_docs/uploads/pasted-1779304398633-0.png` — visual reference

The app is the implementation of these sources. Update the sources first if the
design needs to change; do not redesign in Dart.
