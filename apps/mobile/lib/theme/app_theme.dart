import "package:flutter/material.dart";

class SyrixColors {
  static const background = Color(0xFF13111C);
  static const surface = Color(0xFF1E1B2E);
  static const surfaceAlt = Color(0xFF272136);
  static const primary = Color(0xFF6C5CE7);
  static const primaryDark = Color(0xFF5A4BD1);
  static const cyan = Color(0xFF00E5FF);
  static const textPrimary = Color(0xFFF1F5F9);
  static const textMuted = Color(0xFF9B95B3);
  static const border = Color(0xFF2E2740);
  static const danger = Color(0xFFEF4444);
  static const success = Color(0xFF22C55E);
  static const verifiedBadge = Color(0xFF6C5CE7);

  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, cyan],
  );
}

ThemeData buildSyrixTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: SyrixColors.background,
    colorScheme: ColorScheme.dark(
      primary: SyrixColors.primary,
      surface: SyrixColors.surface,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: SyrixColors.surfaceAlt,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: SyrixColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: SyrixColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: SyrixColors.primary),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: SyrixColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
  );
}
