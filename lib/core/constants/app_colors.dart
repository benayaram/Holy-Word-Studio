import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFFFCA311); // Gold
  static const Color primaryLight = Color(0xFFFFC04D); // Light Gold
  static const Color secondary = Color(0xFF0A1128); // Richer Navy
  static const Color accent = Color(0xFF000000); // Black
  static const Color accentLight = Color(0xFF1E293B); // Dark Slate
  static const Color background = Color(0xFFF8F9FA); // Slightly off-white background
  static const Color surface = Color(0xFFFFFFFF); // Pure white surface
  static const Color surfaceVariant = Color(0xFFF1F3F5); // Light gray surface
  static const Color error = Color(0xFFD32F2F); // Standard Red

  static const Color textPrimary = Color(0xFF0A1128); // Navy for primary text
  static const Color textSecondary = Color(0xFF64748B); // Slate for subtext

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFCA311), Color(0xFF14213D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF000000), Color(0xFF14213D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static Color glassColor = Colors.white;
  static Color glassBackground = Colors.white.withValues(alpha: 0.1);
  static Color glassBorder = Colors.white.withValues(alpha: 0.2);
  static Color glassShadow = Colors.black.withValues(alpha: 0.05);
}
