import 'package:flutter/material.dart';

/// Centralized color palette for Kheyrukum Mobile App.
class AppColors {
  AppColors._();

  // Primary Theme Surfaces (Refined Obsidian & Midnight Slate)
  static const Color background = Color(0xFF0B1120); // Deep Obsidian Navy
  static const Color backgroundDark = Color(0xFF070B14); // Deeper Midnight
  static const Color surfaceNav = Color(0xFF131C31); // Elevated Nav Bar & Cards
  static const Color surfaceCard = Color(0xFF131C31);
  static const Color surfaceLight = Color(0xFF1E293B);
  static const Color borderSubtle = Color(0xFF23304C);

  // Accents & Glows (Cohesive Kheyrukum Emerald & Warm Gold)
  static const Color accentAmber = Color(0xFFD4AF37); // Warm Islamic Gold
  static const Color accentAmberLight = Color(0xFFE8C968);
  static const Color accentTeal = Color(0xFF0D9488); // Deep Emerald Teal
  static const Color accentTealLight = Color(0xFF2DD4BF);
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
