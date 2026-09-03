import 'package:flutter/material.dart';

class AppColors {
  static const Color brand = Color(0xFF1A73E8);
  static const Color brandDark = Color(0xFF1557B0);
  static const Color brandLight = Color(0xFFE8F0FE);
  static const Color success = Color(0xFF10B981);
  static const Color successDark = Color(0xFF059669);
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color lightBg = Color(0xFFF8F9FA);
  static const Color lightCard = Colors.white;
  static const Color lightBorder = Color(0xFFE5E7EB);
  static const Color lightDivider = Color(0xFFF3F4F6);
  static const Color darkBg = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkCard = Color(0xFF1E293B);
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkDivider = Color(0xFF334155);
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
}

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brand,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.lightBg,
      cardColor: AppColors.lightCard,
      dividerColor: AppColors.lightDivider,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.lightCard,
        elevation: 0,
      ),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: Brightness.dark,
    ).copyWith(
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkTextPrimary,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.darkBg,
      cardColor: AppColors.darkCard,
      dividerColor: AppColors.darkDivider,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
      ),
      textTheme: const TextTheme().apply(
        bodyColor: AppColors.darkTextPrimary,
        displayColor: AppColors.darkTextPrimary,
      ),
      iconTheme: const IconThemeData(color: AppColors.darkTextPrimary),
    );
  }
}

extension ThemeHelpers on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get appBackground => isDark ? AppColors.darkBg : AppColors.lightBg;
  Color get cardBackground => isDark ? AppColors.darkCard : AppColors.lightCard;
  Color get borderColor => isDark ? AppColors.darkBorder : AppColors.lightBorder;
  Color get dividerColor => isDark ? AppColors.darkDivider : AppColors.lightDivider;
  Color get textPrimary => isDark ? AppColors.darkTextPrimary : const Color(0xFF1F2937);
  Color get textSecondary => isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280);
  Color get surfaceVariant => isDark ? AppColors.darkSurface : AppColors.lightBg;
  Color get shadowColor => isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.05);
}
