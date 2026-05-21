import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens — see Flutter Handoff.md §2.
///
/// Strict rule (Handoff R4): widgets MUST consume colors/sizes from here.
/// Do not hardcode raw values in widgets.

class AppColors {
  AppColors._();

  /// Brand seed — forest green (L0.55 C0.13 H155 oklch → sRGB).
  /// Handoff §2.
  static const Color seed = Color(0xFF1F8A5B);
}

class AppRadii {
  AppRadii._();
  static const double card = 16.0;
  static const double cardLarge = 20.0; // hero card
  static const double heroIcon = 28.0; // detail screen large icon
  static const double switchTrack = 16.0; // M3 default
  static const double sheet = 28.0; // bottom sheet top corners
  static const double button = 24.0; // 48dp filled button
  static const double fab = 16.0; // M3 medium FAB
}

class AppSpacing {
  AppSpacing._();
  static const double xs = 4.0;
  static const double s = 8.0;
  static const double m = 12.0;
  static const double l = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
}

/// Animation timings — see Flutter Handoff.md §7.
class AppMotion {
  AppMotion._();
  static const Duration cardGlyph = Duration(milliseconds: 200);
  static const Duration bigSwitchPanel = Duration(milliseconds: 280);
  static const Duration statTile = Duration(milliseconds: 240);
  static const Duration statusDotPulse = Duration(milliseconds: 2400);
  static const Duration sparkline = Duration(milliseconds: 250);

  /// Material 3 signature "emphasized" curve.
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
}

/// Status colors not part of the M3 scheme.
class AppStatus {
  AppStatus._();
  // oklch(0.62 0.13 150) → approximate sRGB green
  static const Color success = Color(0xFF1E9E63);
  static const Color successDark = Color(0xFF7BD3A2);
}

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: brightness,
    );
    final textTheme = _textTheme(scheme);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      cardTheme: CardThemeData(
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
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelSmall),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainer,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.sheet),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
      ),
    );
  }

  /// Type scale per Handoff §2 — Outfit for numerics/display,
  /// DM Sans for body/UI, JetBrains Mono for entity ids.
  static TextTheme _textTheme(ColorScheme c) {
    final display = GoogleFonts.outfitTextTheme();
    final body = GoogleFonts.dmSansTextTheme();
    return body
        .copyWith(
          displayLarge: display.displayLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          displayMedium: display.displayMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          displaySmall: display.displaySmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          headlineLarge: display.headlineLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          headlineMedium: display.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          headlineSmall: display.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          titleLarge: display.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          titleMedium: display.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        )
        .apply(bodyColor: c.onSurface, displayColor: c.onSurface);
  }

  /// Monospace style for entity ids / IPs (Handoff §2 type scale table).
  static TextStyle monoStyle(ColorScheme scheme) {
    return GoogleFonts.jetBrainsMono(
      textStyle: TextStyle(
        fontSize: 12,
        color: scheme.onSurfaceVariant,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}
