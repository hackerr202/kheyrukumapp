import 'package:flutter/material.dart';

/// Centralized color palette for Kheyrukum Mobile App.
class AppColors {
  AppColors._();

  // Primary Theme Surfaces
  static const Color background = Color(0xFF0F172A); // Deep Navy Blue
  static const Color backgroundDark = Color(0xFF0A192F); // Deeper Midnight Blue
  static const Color surfaceNav = Color(0xFF1E293B); // Nav Bar Pill & Cards
  static const Color surfaceCard = Color(0xFF1E293B);
  static const Color surfaceLight = Color(0xFF334155);
  static const Color borderSubtle = Color(0xFF334155);

  // Accents & Glows
  static const Color accentAmber = Color(0xFFFFC107); // Warm Amber
  static const Color accentAmberLight = Color(0xFFFFD54F);
  static const Color accentTeal = Color(0xFF00BCD4); // Soft Teal
  static const Color accentTealLight = Color(0xFF4DD0E1);
  static const Color accentEmerald = Color(0xFF10B981);
  static const Color accentCoral = Color(0xFFF43F5E);

  // Typography Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF94A3B8); // Muted slate gray
  static const Color textMuted = Color(0xFF64748B);

  // Light Theme Surfaces & Typography
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceCardLight = Color(0xFFFFFFFF);
  static const Color surfaceNavLight = Color(0xFFF1F5F9);
  static const Color borderSubtleLight = Color(0xFFE2E8F0);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569);
  static const Color textMutedLight = Color(0xFF94A3B8);

  // Gradients
  static const LinearGradient journeyGradient = LinearGradient(
    colors: [accentAmber, accentTeal],
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
  );

  static const LinearGradient beadGradient = LinearGradient(
    colors: [accentAmber, Color(0xFFFFA000)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient beadTealGradient = LinearGradient(
    colors: [accentTeal, Color(0xFF0097A7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
