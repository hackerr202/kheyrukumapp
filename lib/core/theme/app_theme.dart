import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/local_storage_service.dart';
import 'app_colors.dart';

/// Flagship Material 3 Theme configuration for Kheyrukum Islamic Center.
/// Supports Warm Sanctuary (Light), Emerald Night (Dark), and System Auto mode,
/// caching built ThemeData per (brightness, languageCode) with Arabic & Ethiopic
/// font fallback for crisp trilingual typography.
class AppTheme {
  AppTheme._();

  static const String _themeStorageKey = 'app_theme_mode';

  /// Reactive theme notifier (defaults to Warm Sanctuary Light Mode)
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  static final Map<String, ThemeData> _cachedThemes = {};

  static bool get isDarkMode => themeModeNotifier.value == ThemeMode.dark;

  /// Restore persisted theme mode on application startup.
  static Future<void> loadSavedTheme() async {
    final saved = await LocalStorageService.instance.getString(_themeStorageKey);
    if (saved == 'dark') {
      themeModeNotifier.value = ThemeMode.dark;
    } else if (saved == 'system') {
      themeModeNotifier.value = ThemeMode.system;
    } else if (saved == 'light') {
      themeModeNotifier.value = ThemeMode.light;
    }
  }

  static Future<void> toggleTheme() async {
    await setThemeMode(isDarkMode ? ThemeMode.light : ThemeMode.dark);
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    final encoded = mode == ThemeMode.dark
        ? 'dark'
        : (mode == ThemeMode.system ? 'system' : 'light');
    await LocalStorageService.instance.saveString(_themeStorageKey, encoded);
  }

  static ThemeData get lightTheme =>
      themeFor(Brightness.light, const Locale('en'));

  static ThemeData get darkTheme =>
      themeFor(Brightness.dark, const Locale('en'));

  static ThemeData themeFor(Brightness brightness, Locale locale) {
    final key = '${brightness.name}_${locale.languageCode}';
    return _cachedThemes.putIfAbsent(
      key,
      () => _buildTheme(brightness, locale),
    );
  }

  static List<String> _fallbackFamiliesFor(Locale locale) {
    final arabic = GoogleFonts.getFont('Noto Naskh Arabic').fontFamily;
    final ethiopic = GoogleFonts.getFont('Noto Sans Ethiopic').fontFamily;
    if (locale.languageCode == 'ar') {
      return [
        if (arabic != null) arabic,
        if (ethiopic != null) ethiopic,
      ];
    }
    if (locale.languageCode == 'am') {
      return [
        if (ethiopic != null) ethiopic,
        if (arabic != null) arabic,
      ];
    }
    return [
      if (arabic != null) arabic,
      if (ethiopic != null) ethiopic,
    ];
  }

  static ThemeData _buildTheme(Brightness brightness, Locale locale) {
    final isDark = brightness == Brightness.dark;
    final p = isDark ? AppColors.darkPalette : AppColors.lightPalette;
    final fallbacks = _fallbackFamiliesFor(locale);
    final rawBase = GoogleFonts.plusJakartaSansTextTheme(
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    );

    TextStyle styleWithFallback(
      double fontSize, {
      FontWeight fontWeight = FontWeight.w400,
      required Color color,
      double? letterSpacing,
    }) {
      return GoogleFonts.plusJakartaSans(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
      ).copyWith(fontFamilyFallback: fallbacks);
    }

    final colorScheme = isDark
        ? ColorScheme.dark(
            primary: p.primary,
            secondary: p.gold,
            tertiary: p.info,
            surface: p.surface,
            error: p.danger,
            onPrimary: p.onPrimary,
            onSecondary: const Color(0xFF1A1405),
            onSurface: p.ink,
            onError: Colors.black,
            outline: p.border,
          )
        : ColorScheme.light(
            primary: p.primary,
            secondary: p.gold,
            tertiary: p.info,
            surface: p.surface,
            error: p.danger,
            onPrimary: p.onPrimary,
            onSecondary: Colors.white,
            onSurface: p.ink,
            onError: Colors.white,
            outline: p.border,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: p.canvas,
      cardColor: p.surface,
      dividerColor: p.border,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: p.surface,
        foregroundColor: p.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: styleWithFallback(
          18,
          fontWeight: FontWeight.w700,
          color: p.ink,
          letterSpacing: isDark ? -0.3 : -0.3,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: isDark ? 10 : 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: p.border),
        ),
        titleTextStyle: styleWithFallback(
          18,
          fontWeight: FontWeight.w700,
          color: p.ink,
        ),
        contentTextStyle: styleWithFallback(
          14,
          color: p.inkSecondary,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: p.primary,
        labelColor: p.primary,
        unselectedLabelColor: p.inkSecondary,
        dividerColor: p.border,
        labelStyle: styleWithFallback(
          13,
          fontWeight: FontWeight.w700,
          color: p.primary,
        ),
        unselectedLabelStyle: styleWithFallback(
          13,
          fontWeight: FontWeight.w500,
          color: p.inkSecondary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? p.canvas : p.surfaceSubtle,
        labelStyle: styleWithFallback(13.5, color: p.inkSecondary),
        floatingLabelStyle: styleWithFallback(
          13.5,
          fontWeight: FontWeight.w600,
          color: p.primary,
        ),
        hintStyle: styleWithFallback(13, color: p.inkMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.primary, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          textStyle: styleWithFallback(
            13.5,
            fontWeight: FontWeight.w700,
            color: p.onPrimary,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.ink,
          side: BorderSide(color: p.border),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: styleWithFallback(
            13,
            fontWeight: FontWeight.w600,
            color: p.ink,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primary,
          textStyle: styleWithFallback(
            13,
            fontWeight: FontWeight.w600,
            color: p.primary,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? p.surfaceSubtle : p.ink,
        contentTextStyle: styleWithFallback(
          13,
          fontWeight: FontWeight.w500,
          color: isDark ? p.ink : Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(
        color: p.border,
        thickness: 1,
        space: 1,
      ),
      textTheme: _buildTextTheme(rawBase, p, fallbacks, styleWithFallback),
    );
  }

  static TextTheme _buildTextTheme(
    TextTheme base,
    AppPalette p,
    List<String> fallbacks,
    TextStyle Function(
      double fontSize, {
      FontWeight fontWeight,
      required Color color,
      double? letterSpacing,
    }) styleWithFallback,
  ) {
    return base.copyWith(
      displayLarge: styleWithFallback(
        32,
        fontWeight: FontWeight.w800,
        color: p.ink,
        letterSpacing: -0.7,
      ),
      headlineMedium: styleWithFallback(
        24,
        fontWeight: FontWeight.w700,
        color: p.ink,
        letterSpacing: -0.4,
      ),
      titleLarge: styleWithFallback(
        20,
        fontWeight: FontWeight.w700,
        color: p.ink,
        letterSpacing: -0.3,
      ),
      titleMedium: styleWithFallback(
        16,
        fontWeight: FontWeight.w600,
        color: p.ink,
      ),
      titleSmall: styleWithFallback(
        14,
        fontWeight: FontWeight.w600,
        color: p.ink,
      ),
      bodyLarge: styleWithFallback(15, color: p.ink),
      bodyMedium: styleWithFallback(13.5, color: p.inkSecondary),
      bodySmall: styleWithFallback(12, color: p.inkMuted),
      labelLarge: styleWithFallback(
        13.5,
        fontWeight: FontWeight.w700,
        color: p.primary,
      ),
      labelMedium: styleWithFallback(
        12,
        fontWeight: FontWeight.w600,
        color: p.inkSecondary,
      ),
      labelSmall: styleWithFallback(
        11,
        fontWeight: FontWeight.w600,
        color: p.inkMuted,
      ),
    );
  }
}
