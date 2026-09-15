import "package:flutter/material.dart";

class SyrixColors {
  static const background = Color(0xFF13111C);
  static const surface = Color(0xFF1E1B2E);
  static const surfaceAlt = Color(0xFF26223A);
  static const primary = Color(0xFF6C5CE7);
  static const neonPurple = Color(0xFF8A52F3);
  static const primaryDark = Color(0xFF5A4BD1);
  static const cyan = Color(0xFF00E5FF);
  static const neonCyan = Color(0xFF00E5FF);
  static const textPrimary = Color(0xFFF1F5F9);
  static const textMuted = Color(0xFF9B95B3);
  static const border = Color(0xFF2E2740);
  static const borderLight = Color(0xFF3B3354);
  static const danger = Color(0xFFEF4444);
  static const success = Color(0xFF22C55E);
  static const verifiedBadge = Color(0xFF8A52F3);

  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [neonPurple, cyan],
  );

  static const purpleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [neonPurple, primary],
  );

  static const outgoingBubbleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9B51E0), Color(0xFF6C5CE7)],
  );

  static const liveGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [neonPurple, cyan],
  );
}

ThemeData buildSyrixTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: SyrixColors.background,
    cardColor: SyrixColors.surface,
    colorScheme: const ColorScheme.dark(
      primary: SyrixColors.primary,
      secondary: SyrixColors.cyan,
      surface: SyrixColors.surface,
      error: SyrixColors.danger,
      onPrimary: Colors.white,
      onSecondary: Colors.black,
      onSurface: SyrixColors.textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: SyrixColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: SyrixColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.3,
      ),
      iconTheme: IconThemeData(color: SyrixColors.textPrimary),
    ),
    cardTheme: CardTheme(
      color: SyrixColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: SyrixColors.border),
      ),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: SyrixColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: SyrixColors.border),
      ),
      titleTextStyle: const TextStyle(
        color: SyrixColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: SyrixColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: SyrixColors.border,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: SyrixColors.surfaceAlt,
      hintStyle: const TextStyle(color: SyrixColors.textMuted, fontSize: 14),
      labelStyle: const TextStyle(color: SyrixColors.textMuted, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: SyrixColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: SyrixColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: SyrixColors.neonPurple, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: SyrixColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: SyrixColors.cyan,
        side: const BorderSide(color: SyrixColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
  );
}
