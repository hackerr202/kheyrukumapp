import 'package:flutter/material.dart';

/// Immutable theme-resolved palette for Kheyrukum Islamic Center.
/// Access via `AppColors.of(context)` across all screens and components.
class AppPalette {
  final bool isDark;
  final Color canvas;
  final Color surface;
  final Color surfaceSubtle;
  final Color border;
  final Color ink;
  final Color inkSecondary;
  final Color inkMuted;
  final Color primary;
  final Color primarySoft;
  final Color onPrimary;
  final Color gold;
  final Color goldSoft;
  final Color success;
  final Color warning;
  final Color danger;
  final Color excused;
  final Color info;
  final LinearGradient heroGradient;

  const AppPalette({
    required this.isDark,
    required this.canvas,
    required this.surface,
    required this.surfaceSubtle,
    required this.border,
    required this.ink,
    required this.inkSecondary,
    required this.inkMuted,
    required this.primary,
    required this.primarySoft,
    required this.onPrimary,
    required this.gold,
    required this.goldSoft,
    required this.success,
    required this.warning,
    required this.danger,
    required this.excused,
    required this.info,
    required this.heroGradient,
  });
}

/// Centralized flagship color tokens for Kheyrukum Islamic Center.
/// Grounded in the official school crest: Deep Pine Teal, Warm Burnished Gold,
/// Warm Sanctuary Ivory (Light), and Emerald Night (Dark).
class AppColors {
  AppColors._();

  // Official Brand Tokens
  static const Color pineDeep = Color(0xFF044B47);
  static const Color pinePrimary = Color(0xFF066E68);
  static const Color pineRich = Color(0xFF0A857E);
  static const Color pineJade = Color(0xFF2CB5AA);
  static const Color goldPrimary = Color(0xFFD9961E);
  static const Color goldWarm = Color(0xFFF2B63D);
  static const Color goldSoft = Color(0xFFFDF4E3);

  // Dark Theme Surfaces ("Emerald Night")
  static const Color background = Color(0xFF071312);
  static const Color backgroundDark = Color(0xFF040C0B);
  static const Color surfaceNav = Color(0xFF0E1D1C);
  static const Color surfaceCard = Color(0xFF0F201F);
  static const Color surfaceLight = Color(0xFF162C2A);
  static const Color borderSubtle = Color(0xFF1F3836);

  // Dark Typography
  static const Color textPrimary = Color(0xFFF5F3EE);
  static const Color textSecondary = Color(0xFF9BB0AD);
  static const Color textMuted = Color(0xFF637B78);

  // Light Theme Surfaces ("Warm Sanctuary")
  static const Color canvasLight = Color(0xFFF7F5F0);
  static const Color backgroundLight = canvasLight;
  static const Color surfaceCardLight = Color(0xFFFFFFFF);
  static const Color surfaceSubtleLight = Color(0xFFF0EDE6);
  static const Color surfaceNavLight = surfaceSubtleLight;
  static const Color borderSubtleLight = Color(0xFFE5DFD4);

  // Light Typography
  static const Color textPrimaryLight = Color(0xFF102322);
  static const Color textSecondaryLight = Color(0xFF526664);
  static const Color textMutedLight = Color(0xFF889997);

  // Semantic Status Tokens
  static const Color statusSuccessLight = Color(0xFF15803D);
  static const Color statusSuccessDark = Color(0xFF34D399);
  static const Color statusWarningLight = Color(0xFFC97A0C);
  static const Color statusWarningDark = Color(0xFFFBBF24);
  static const Color statusDangerLight = Color(0xFFDC2626);
  static const Color statusDangerDark = Color(0xFFF87171);
  static const Color statusExcusedLight = Color(0xFF6D5BD0);
  static const Color statusExcusedDark = Color(0xFFA78BFA);
  static const Color statusInfoLight = Color(0xFF0B7A75);
  static const Color statusInfoDark = Color(0xFF2DD4BF);

  // Harmonized Legacy Aliases (Backwards Compatibility)
  static const Color accentAmber = goldPrimary;
  static const Color accentAmberLight = goldWarm;
  static const Color accentTeal = pinePrimary;
  static const Color accentTealLight = pineJade;
  static const Color accentEmerald = statusSuccessDark;
  static const Color accentCoral = statusDangerLight;

  // Gradients
  static const LinearGradient journeyGradient = LinearGradient(
    colors: [goldWarm, pineRich],
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
  );

  static const LinearGradient beadGradient = LinearGradient(
    colors: [goldWarm, goldPrimary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient beadTealGradient = LinearGradient(
    colors: [pineRich, pineDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF162C2A), Color(0xFF0B1918)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroLightGradient = LinearGradient(
    colors: [pinePrimary, Color(0xFF044643)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroDarkGradient = LinearGradient(
    colors: [Color(0xFF0E2D2B), Color(0xFF081B1A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const AppPalette lightPalette = AppPalette(
    isDark: false,
    canvas: canvasLight,
    surface: surfaceCardLight,
    surfaceSubtle: surfaceSubtleLight,
    border: borderSubtleLight,
    ink: textPrimaryLight,
    inkSecondary: textSecondaryLight,
    inkMuted: textMutedLight,
    primary: pinePrimary,
    primarySoft: Color(0xFFE6F3F2),
    onPrimary: Colors.white,
    gold: goldPrimary,
    goldSoft: goldSoft,
    success: statusSuccessLight,
    warning: statusWarningLight,
    danger: statusDangerLight,
    excused: statusExcusedLight,
    info: statusInfoLight,
    heroGradient: heroLightGradient,
  );

  static const AppPalette darkPalette = AppPalette(
    isDark: true,
    canvas: background,
    surface: surfaceCard,
    surfaceSubtle: surfaceLight,
    border: borderSubtle,
    ink: textPrimary,
    inkSecondary: textSecondary,
    inkMuted: textMuted,
    primary: pineJade,
    primarySoft: Color(0xFF123330),
    onPrimary: Color(0xFF041413),
    gold: goldWarm,
    goldSoft: Color(0xFF282010),
    success: statusSuccessDark,
    warning: statusWarningDark,
    danger: statusDangerDark,
    excused: statusExcusedDark,
    info: statusInfoDark,
    heroGradient: heroDarkGradient,
  );

  /// Resolve the active [AppPalette] from the widget tree's [ThemeData.brightness].
  static AppPalette of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkPalette
        : lightPalette;
  }
}
