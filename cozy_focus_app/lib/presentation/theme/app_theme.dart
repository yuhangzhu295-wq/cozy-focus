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
  static const Color primarySage = Color(0xFF5E8D6D);
  static const Color primaryDark = Color(0xFF4A7256);
  static const Color primaryLight = Color(0xFFEAF2EB);
  static const Color accentPeach = Color(0xFFE28768);
  static const Color accentPeachLight = Color(0xFFFDF1EB);
  static const Color accentGold = Color(0xFFE5A93C);
  static const Color accentGoldLight = Color(0xFFFEF8EC);

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
