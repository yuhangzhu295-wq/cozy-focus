import 'package:flutter/material.dart';

/// Cozy Focus Design System Tokens & Theme
/// Aligned directly with designs/: warm pastel, cozy atmosphere, rounded cards,
/// low stress, and accessible high-contrast text.
class AppColors {
  AppColors._();

  // Backgrounds
  static const Color background = Color(0xFFFBF8F2);
  static const Color backgroundWarm = Color(0xFFF5EFE6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF2ECE1);

  // Focus Immersion / Dark Room
  static const Color focusNightBg = Color(0xFF1E232A);
  static const Color focusNightSurface = Color(0xFF272F38);

  // Brand Accents
  //
  // [primarySage] is the app's primary: filled buttons, the running ring's arc,
  // selection, and the 192 accent sites that use it directly. Its value is
  // measured from the design boards rather than chosen. Across the sixteen
  // boards the green that fills the primary buttons is `#44714B` — 125,256
  // pixels of it, present on every board — while the previous `#5E8D6D` matched
  // only 1,468 pixels, the anti-aliased fringe of the deeper green against the
  // cream background rather than any fill. The other two tokens were checked the
  // same way and are correct as they stand: [primaryLight] `#EAF2EB` matches
  // 162,685 pixels and [primaryDark] `#4A7256` matches 35,771.
  //
  // `tools/qa/palette_report.py` and `tools/qa/sample_colors.py` are the tools
  // that measured this, and `test/theme/primary_green_matches_design_test.dart`
  // pins the value so it cannot drift back.
  static const Color primarySage = Color(0xFF44714B);

  /// The designs' second green, used for emphasis text and icons.
  ///
  /// Despite the name this is not a shade of [primarySage]: the two sit within
  /// 3% of each other in luminance, and this one is the bluer of the pair. It
  /// keeps its name because it is what 70 call sites already read as "the
  /// darker green", and renaming it would be churn without a visual change.
  static const Color primaryDark = Color(0xFF4A7256);
  static const Color primaryLight = Color(0xFFEAF2EB);
  static const Color accentPeach = Color(0xFFE28768);
  static const Color accentPeachLight = Color(0xFFFDF1EB);
  static const Color accentGold = Color(0xFFE5A93C);
  static const Color accentGoldLight = Color(0xFFFEF8EC);

  /// The green the designs fill their bar charts with.
  ///
  /// Measured from the boards rather than derived from [primarySage]. Page 01's
  /// home chart fills its tallest bar with `#7AB278` and its shortest with
  /// `#CEE8C1`; a tint of `#44714B` comes out grey beside them, because the
  /// chart green is a more saturated one rather than a lighter brand green. The
  /// faint value is what a bucket holding almost nothing is drawn in, so the low
  /// end reads as "barely any" instead of as a different category.
  static const Color chartBar = Color(0xFF7AB278);
  static const Color chartBarFaint = Color(0xFFCEE8C1);

  /// Ink for the large focus timer figure.
  ///
  /// Sampled from the approved page renders rather than chosen: the `25:00`
  /// figure on page 01 measures `#345C48` across its whole stroke, while page
  /// 03's timer measures `#000000`. So the big timer is not simply
  /// [textPrimary] — on Home it is deliberately a deep sage, which is what
  /// gives the figure its "growing" character instead of reading as a neutral
  /// number.
  static const Color timerInk = Color(0xFF345C48);

  // Category Colors
  static const Color catStudy = Color(0xFF8BA4C8);
  static const Color catWork = Color(0xFFE08373);
  static const Color catReading = Color(0xFF7CAFA1);
  static const Color catLife = Color(0xFFF0B367);
  static const Color catOther = Color(0xFFA5A9A7);

  // Text
  static const Color textPrimary = Color(0xFF2D312E);
  static const Color textSecondary = Color(0xFF7A807C);
  static const Color textTertiary = Color(0xFFA6ABA7);
  static const Color textLight = Color(0xFFFFFFFF);
  static const Color textLightSecondary = Color(0xFFB0B8B2);

  // Dividers & Borders
  static const Color border = Color(0xFFEDE6DA);
  static const Color borderLight = Color(0xFFF4EFE6);
}

class AppRadius {
  AppRadius._();
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double pill = 999.0;
}

/// Layout widths the screens share.
class AppLayout {
  AppLayout._();

  /// The widest a report reads at.
  ///
  /// The report pages are single columns of cards, and the app does not lock its
  /// orientation, so on a landscape phone the column was laid out across ~1100dp:
  /// the year heatmap's `spaceBetween` row spread its 31 fixed-size days 27dp
  /// apart and stopped reading as a calendar, and the bar charts stretched into
  /// thin spikes. Capping the column keeps every card at the width it was drawn
  /// for and centres the page. It never binds in portrait — a 411dp phone is
  /// narrower than this — so the design's own layout is untouched.
  static const double reportMaxWidth = 560.0;

  /// The gutter the report pages use, on a screen [screenWidth] wide.
  ///
  /// The design's own 20dp whenever that already holds the content to
  /// [reportMaxWidth], and half the excess when it does not — which is what
  /// centres the column. Written as a `max` rather than a branch so the two
  /// cases meet without a step: at exactly [reportMaxWidth] + 40 both give 20.
  static double reportGutter(double screenWidth) {
    final excess = (screenWidth - reportMaxWidth) / 2;
    return excess > 20.0 ? excess : 20.0;
  }
}

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primarySage,
        primary: AppColors.primarySage,
        surface: AppColors.surface,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primarySage,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
    );
  }
}
