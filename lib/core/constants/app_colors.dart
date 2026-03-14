import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFFFCA311); // Gold
  static const Color primaryLight = Color(0xFFFFC04D); // Light Gold
  static const Color secondary = Color(0xFF14213D); // Deep Navy
  static const Color accent = Color(0xFF000000); // Black
  static const Color accentLight = Color(0xFF1E293B); // Dark Slate
  static const Color background = Color(0xFFFFFFFF); // Clean White
  static const Color surface = Color(0xFFE5E5E5); // Light Gray
  static const Color error = Color(0xFFD32F2F); // Standard Red

  static const Color textPrimary = Color(0xFF000000); // Black for readability
  static const Color textSecondary = Color(0xFF14213D); // Deep Navy for subtext

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
