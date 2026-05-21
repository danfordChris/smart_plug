# Smart Plugs — Flutter Implementation Handoff

Maps everything in **Smart Plugs App.html** to concrete Flutter / Material 3 code. Read alongside the original PRD (file structure, API, acceptance criteria — already defined there).

This document is the source of truth for: design tokens, widget mapping, layout specs per screen, and behavior expectations. The HTML prototype is faithful to Material 3, so most components map 1:1 to Flutter's `material` library.

---

## 1. Project setup

```yaml
# pubspec.yaml — add these
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1
  dio: ^5.4.0
  flutter_secure_storage: ^9.0.0
  web_socket_channel: ^2.4.0
  fl_chart: ^0.66.0
  google_fonts: ^6.1.0
  intl: ^0.19.0

flutter:
  uses-material-3: true
  fonts:
    # Outfit + DM Sans served via google_fonts — no asset declarations needed
```

`main.dart` boilerplate:

```dart
void main() => runApp(const ProviderScope(child: SmartPlugsApp()));

class SmartPlugsApp extends ConsumerWidget {
  const SmartPlugsApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Smart Plugs',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system, // matches "adaptive theme" requirement
      home: const RootGate(), // routes to Setup or Dashboard
    );
  }
}
```

---

## 2. Design tokens → Dart

Drop into `lib/config/theme.dart`. Hues come from oklch in the prototype — converted to Material `Color` (sRGB).

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Brand — forest green (primary at L0.55 C0.13 H155 in oklch)
  static const Color seed = Color(0xFF1F8A5B); // ColorScheme.fromSeed input
}

class AppRadii {
  static const card        = 16.0;
  static const cardLarge   = 20.0;  // hero card
  static const heroIcon    = 28.0;  // detail screen large icon
  static const switchTrack = 16.0;  // standard M3 Switch — handled by Switch widget
  static const sheet       = 28.0;  // bottom sheet top corners
  static const button      = 24.0;  // 48dp filled button
  static const fab         = 16.0;  // M3 medium FAB
}

class AppSpacing {
  static const xs = 4.0;
  static const s  = 8.0;
  static const m  = 12.0;
  static const l  = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
}

class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark()  => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: b,
    );
    final textTheme = _textTheme(scheme);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      // Switches: M3 default already matches the prototype
      cardTheme: CardTheme(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelSmall,
        ),
      ),
    );
  }

  static TextTheme _textTheme(ColorScheme c) {
    final display = GoogleFonts.outfitTextTheme();
    final body    = GoogleFonts.dmSansTextTheme();
    // Map: numeric readouts use Outfit (display), UI copy uses DM Sans (body)
    return body.copyWith(
      displayLarge:   display.displayLarge?.copyWith(
        fontWeight: FontWeight.w600, letterSpacing: -0.5,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      displayMedium:  display.displayMedium?.copyWith(
        fontWeight: FontWeight.w600, letterSpacing: -0.5,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      headlineLarge:  display.headlineLarge?.copyWith(fontWeight: FontWeight.w600),
      headlineMedium: display.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
      titleLarge:     display.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      // body* and label* stay DM Sans
    ).apply(
      bodyColor: c.onSurface,
      displayColor: c.onSurface,
    );
  }
}
```

**Type scale recipe** (matches prototype sizes):
| Use | Style | Font | Size |
|---|---|---|---|
| Power readout (card) | `displayMedium` | Outfit 600 | 44 |
| Power readout (stat tile) | `displayMedium` | Outfit 600 | 32 |
| Section header | `titleMedium` | Outfit 600 | 17 |
| Greeting "Good evening" | `headlineSmall` | Outfit 600 | 22 |
| Plug name | `titleLarge` | Outfit 600 | 20 |
| Body | `bodyMedium` | DM Sans 400 | 14 |
| Helper / caption | `bodySmall` | DM Sans 400 | 12 |
| Mono (entity_id, IPs) | `bodySmall` | JetBrains Mono 400 | 12 |

`fontFeatures: [FontFeature.tabularFigures()]` is **required** on any auto-updating number — power readings, voltages, timestamps. Without it digits jitter as values change.

---

## 3. Component mapping (prototype → Flutter)

| Prototype element | Flutter widget | Notes |
|---|---|---|
| M3 Switch | `Switch` | M3 default. Use `Switch.adaptive` if you want iOS look on Cupertino, but spec says M3 throughout — keep `Switch`. |
| Outlined text field | `TextField` w/ `OutlineInputBorder` | Use `obscureText` toggle for the token field. |
| Card | `Card` | Color comes from `surfaceContainerLow`. |
| FAB add button | `FloatingActionButton.extended` | `shape: RoundedRectangleBorder(borderRadius: 16)` for M3 medium FAB. |
| Bottom nav | `NavigationBar` + `NavigationDestination` | The center "+" tab is custom — see §4.2. |
| Pull-to-refresh | `RefreshIndicator` | Returns Future; complete it when the API call finishes. |
| Sheet (Add device) | `showModalBottomSheet` | `shape: RoundedRectangleBorder(top: 28)`, `useSafeArea: true`. |
| App bar | `AppBar` | Plain centerless. For the greeting header, just use a `Padding` + `Row` (not `AppBar`). |
| Sparkline | `fl_chart` `LineChart` | See §5. |
| Weekly bars | `fl_chart` `BarChart` | See §5. |
| Status dot | `Container` w/ `BoxDecoration` | Animate with `TweenAnimationBuilder<Color>`. |
| Skeleton loader | `shimmer` package OR `AnimatedOpacity` | Optional. |
| Hero icon on detail | `Hero(tag: 'plug-${id}')` | Wrap the icon container on both card and detail. |

Things the prototype hand-rolls that **don't need re-implementation** in Flutter:
- Outlined text field floating label — `TextField` does it
- Pull-to-refresh gesture — `RefreshIndicator` does it
- Bottom-nav active indicator pill — `NavigationBar` does it
- Switch animation — `Switch` does it
- Ripple effects — `InkWell` / Material widgets do it

---

## 4. Per-screen specs

### 4.1 Setup (`lib/screens/setup_screen.dart`)

```
Scaffold
└─ SafeArea
   └─ Column
      ├─ AppBar(title: 'Setup')          — only if reachable from settings
      ├─ Expanded > ListView
      │   ├─ HeroHeader                  — 64×64 primaryContainer icon + h1 + sub
      │   ├─ TextField (HA URL)          — keyboardType: url
      │   ├─ TextField (Token)           — obscureText + IconButton suffix (eye)
      │   ├─ FilledButton.tonal          — "Test connection"
      │   ├─ ResultCard                  — success / error banner (conditional)
      │   └─ ExpansionTile               — "How to generate a token"
      └─ Bottom action bar
          └─ FilledButton                 — "Save & Continue"
```

**Behavior**:
- `Test Connection` calls `GET /api/` with `Authorization: Bearer <token>`, 5s timeout.
- On 200 → green success card. On any other response → red error card with `Couldn't connect`.
- `Save & Continue` is disabled until `testResult == ok`.
- On save: write `url` and `token` to `flutter_secure_storage`, then `Navigator.pushReplacement` to Dashboard.

### 4.2 Dashboard / Home (`lib/screens/dashboard_screen.dart`)

```
Scaffold
├─ body: SafeArea > RefreshIndicator > CustomScrollView
│   slivers:
│   ├─ SliverToBoxAdapter > GreetingHeader        — "Good evening, Alex"
│   ├─ SliverPadding > SliverList:
│   │   ├─ EnergyHeroCard                          — see §5
│   │   ├─ SectionHeader('Quick access')
│   │   ├─ SizedBox(h: 92) > horizontal ListView   — 5 QuickAccessTiles
│   │   ├─ SectionHeader('Your plugs')
│   │   ├─ PlugCard × N                            — 2 cards (radio, fridge)
│   │   ├─ SectionHeader('Insights & alerts')
│   │   ├─ InsightCard × 3
│   │   └─ ConnectionFooter                        — "100.83.45.15:8123 · via Tailscale"
└─ bottomNavigationBar: SmartBottomNav
```

**`SmartBottomNav`** — custom widget wrapping `NavigationBar` because the center destination is a FAB-style "Add device" button. Two implementation options:

1. **Stack approach (recommended)**: `Stack` containing a 5-destination `NavigationBar` where the middle destination's icon is invisible, plus a positioned `FloatingActionButton` sitting on top of it.
2. **Row approach**: Build the bar manually with `Row` of `Expanded` tabs. More work but full control.

Suggest (1) for fidelity to M3 ripple/indicator behavior.

### 4.3 Detail (`lib/screens/detail_screen.dart`)

```
Scaffold
├─ appBar: AppBar (back arrow only)
└─ body: SafeArea > SingleChildScrollView > Column:
    ├─ Hero(tag: 'plug-${id}') > 96×96 IconContainer
    ├─ Text(name, headlineLarge)
    ├─ EntityIdRow                         — green dot + mono entity_id
    ├─ BigSwitchPanel                      — Container + Switch (large)
    ├─ GridView 2×2 of StatTile            — Power (primary), Voltage, Current, Today
    ├─ SparklineCard                       — fl_chart LineChart, 60 points
    └─ HintCard                            — "Renamed in Home Assistant"
```

`BigSwitchPanel` — its background animates between `surfaceContainerLow` (off) and `colorScheme.primary` (on) via `AnimatedContainer(duration: 280ms)`. When `primary`, the switch needs:

```dart
Switch(
  value: isOn,
  onChanged: onToggle,
  thumbColor: WidgetStatePropertyAll(scheme.primary),
  trackColor: WidgetStatePropertyAll(scheme.onPrimary),
  trackOutlineColor: WidgetStatePropertyAll(scheme.onPrimary),
)
```

This matches the `tone="on-primary"` variant in the prototype (white track + primary thumb).

### 4.4 Insights tab

```
Scaffold body:
  ListView:
    ├─ WeeklyBarChartCard            — fl_chart BarChart, 7 bars, today highlighted
    ├─ SectionHeader('Top appliances today')
    ├─ AppliancesBreakdownCard       — list rows w/ glyph + LinearProgressIndicator + %
    ├─ SectionHeader('Recommendations')
    └─ InsightCard × 4               — same widget as dashboard
```

### 4.5 Settings tab

Native `ListView` with `ListTile`s grouped under `Text` section headers. The poll-interval `Slider` uses `divisions: 11, min: 5, max: 60`.

---

## 5. Data viz (fl_chart)

### Hero sparkline (24 points of hourly kWh)

```dart
LineChart(LineChartData(
  minY: 0,
  gridData: const FlGridData(show: false),
  titlesData: const FlTitlesData(show: false),
  borderData: FlBorderData(show: false),
  lineBarsData: [
    LineChartBarData(
      spots: hourly.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
      isCurved: true,
      curveSmoothness: 0.35,
      barWidth: 1.6,
      color: scheme.onPrimary,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            scheme.onPrimary.withOpacity(0.35),
            scheme.onPrimary.withOpacity(0),
          ],
        ),
      ),
    ),
  ],
))
```

### Detail sparkline (60 points)

Same shape, but `barWidth: 2`, `color: scheme.primary`, and **add the last-point dot**:

```dart
dotData: FlDotData(
  show: true,
  checkToShowDot: (s, _) => s.x == lastIndex,
  getDotPainter: (s, _, __, ___) => FlDotCirclePainter(
    radius: 3.5,
    color: scheme.surface,
    strokeColor: scheme.primary,
    strokeWidth: 2,
  ),
),
```

### Weekly bar chart

```dart
BarChart(BarChartData(
  alignment: BarChartAlignment.spaceBetween,
  maxY: maxKwh * 1.15,
  gridData: const FlGridData(show: false),
  titlesData: FlTitlesData(
    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    bottomTitles: AxisTitles(sideTitles: SideTitles(
      showTitles: true, reservedSize: 22,
      getTitlesWidget: (v, _) => Text(days[v.toInt()], style: ...),
    )),
  ),
  borderData: FlBorderData(show: false),
  barGroups: List.generate(7, (i) => BarChartGroupData(
    x: i,
    barRods: [BarChartRodData(
      toY: data[i],
      color: i == todayIndex ? scheme.primary : scheme.primary.withOpacity(0.35),
      width: 28,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
    )],
  )),
))
```

---

## 6. State management (Riverpod)

```dart
// lib/providers/settings_provider.dart
final settingsProvider = AsyncNotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

// lib/providers/plugs_provider.dart
final plugsProvider = AsyncNotifierProvider<PlugsNotifier, List<Plug>>(
  PlugsNotifier.new,
);

class PlugsNotifier extends AsyncNotifier<List<Plug>> {
  @override Future<List<Plug>> build() async { /* initial fetch */ }
  Future<void> refresh() async { state = AsyncData(await _fetchAll()); }
  Future<void> toggle(String id) async {
    // 1. Optimistic update
    state = AsyncData([
      for (final p in state.requireValue)
        p.id == id ? p.copyWith(state: p.isOn ? PlugState.off : PlugState.on) : p
    ]);
    try {
      await ref.read(haApiProvider).callService(
        isOn ? 'turn_off' : 'turn_on', 'switch.$id',
      );
    } catch (_) {
      // 2. Revert + snackbar
      await refresh();
      _showError('Couldn\'t reach Home Assistant');
    }
  }
}
```

Polling: kick off in `PlugsNotifier.build()`:

```dart
Timer.periodic(const Duration(seconds: 10), (_) => _fetchAll());
ref.onDispose(() => timer.cancel());
```

Or upgrade to WebSocket — subscribe to `state_changed`, filter on `entity_id starts with switch.` or `sensor.radio_` / `sensor.fridge_`.

---

## 7. Animations checklist

All durations are **200–320 ms** per the spec. Use `Curves.easeInOutCubicEmphasized` (Material 3's signature emphasized easing) for state transitions.

| Animation | Widget | Duration |
|---|---|---|
| Card glyph background (off → on) | `AnimatedContainer` | 200 |
| Big switch panel (off → on bg) | `AnimatedContainer` | 280 |
| Switch toggle | built-in `Switch` | 200 |
| Stat tile bg (when primary tinted) | `AnimatedContainer` | 240 |
| Card → Detail | `Hero(tag: 'plug-$id')` | default M3 |
| Status-dot pulse (on state) | `TweenAnimationBuilder` + `repeat` | 2400 |
| Sparkline value update | `LineChart` rebuild | 250 (fl_chart default) |

---

## 8. Accessibility

- All `IconButton`s need `tooltip:` set (Refresh, Settings, Eye/EyeOff).
- Switch widgets: wrap the row containing the Switch in `Semantics(label: 'Radio plug, on. Tap to turn off.')` so the entire row reads as one control.
- Min hit area 48×48 — `FloatingActionButton` and `Switch` already satisfy.
- Honor `MediaQuery.textScaler` — use `Text` defaults, avoid hard `fontSize:` values; the theme covers it.

---

## 9. File map (matches PRD)

```
lib/
├─ main.dart
├─ config/
│   ├─ constants.dart            — HA_DEFAULT_URL, POLL_SECONDS
│   └─ theme.dart                — AppColors, AppTheme, AppRadii, AppSpacing
├─ models/
│   ├─ plug.dart                 — @freezed Plug(id, entityId, name, state, power, voltage, current, energyToday, history)
│   └─ ha_state.dart             — HaStateResponse(state, attributes)
├─ services/
│   ├─ ha_api.dart               — Dio client; getState(), turnOn(), turnOff(), testConnection(), watchEvents()
│   └─ storage.dart              — SecureStorage(read/write/delete) wrapper
├─ providers/
│   ├─ settings_provider.dart    — URL + token persistence; emits AsyncValue<AppSettings>
│   └─ plugs_provider.dart       — list of plugs + polling/WS + optimistic toggle
├─ screens/
│   ├─ setup_screen.dart         — §4.1
│   ├─ dashboard_screen.dart     — §4.2 (the Home tab body)
│   ├─ devices_screen.dart       — list-only variant of dashboard
│   ├─ insights_screen.dart      — §4.4
│   ├─ settings_screen.dart      — §4.5
│   ├─ detail_screen.dart        — §4.3
│   └─ root_gate.dart            — chooses Setup vs HomeScaffold based on storage
├─ widgets/
│   ├─ smart_bottom_nav.dart     — NavigationBar + center FAB
│   ├─ plug_card.dart
│   ├─ stat_tile.dart
│   ├─ energy_hero_card.dart
│   ├─ insight_card.dart
│   ├─ quick_access_tile.dart
│   ├─ connection_banner.dart
│   └─ sparkline.dart            — wraps fl_chart LineChart
└─ utils/
    └─ formatters.dart           — kWh / W / £ / "Xm ago" strings (use intl)
```

---

## 10. Acceptance walkthrough

Test these flows on both iOS simulator and Android emulator:

1. Cold start with no stored token → Setup screen.
2. Paste URL + bad token → Test fails red.
3. Paste URL + good token → Test passes green → Save → Dashboard.
4. Toggle a plug switch → animates instantly. If HA unreachable, switch reverts after 5s timeout, snackbar appears.
5. Pull down on dashboard → spinner appears, readings update.
6. Tap a card → hero-animated transition to Detail. Tap big switch → state updates.
7. Open Insights tab → weekly chart renders, today's bar highlighted.
8. Settings → Forget instance → returns to Setup.
9. Toggle system dark mode → app re-themes without restart.
10. Disable WiFi → red "Disconnected" banner at top of Dashboard with Retry button.

---

## 11. Out of scope (reminder)

Per original PRD: no accounts, no cloud, no push, no automation editor, no history beyond sparklines, no in-app plug pairing. If the user requests one of these later, push back to the HA web UI.
