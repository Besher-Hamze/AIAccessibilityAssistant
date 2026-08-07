import 'package:flutter/material.dart';

class AppColors {
  static const deepTeal = Color(0xFF0B3D3A);
  static const teal = Color(0xFF146B64);
  static const mint = Color(0xFF2A9D8F);
  static const sand = Color(0xFFF4F0E6);
  static const cream = Color(0xFFFAF7F0);
  static const ink = Color(0xFF1A1F1E);
  static const muted = Color(0xFF5C6B68);
  static const coral = Color(0xFFE07A5F);
  static const gold = Color(0xFFD4A373);
  static const success = Color(0xFF2D6A4F);
  static const warning = Color(0xFFBC6C25);
  static const danger = Color(0xFF9B2226);
}

class AppTheme {
  static ThemeData light({bool highContrast = false, bool largeControls = false}) {
    final primary = highContrast ? const Color(0xFF003D33) : AppColors.teal;
    final bg = highContrast ? Colors.white : AppColors.cream;
    final ink = highContrast ? Colors.black : AppColors.ink;
    final base = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      secondary: highContrast ? const Color(0xFF8B1E00) : AppColors.coral,
      surface: bg,
      onPrimary: Colors.white,
      onSurface: ink,
    );

    final textTheme = ThemeData(useMaterial3: true, brightness: Brightness.light)
        .textTheme
        .apply(
          fontFamily: 'Segoe UI',
          bodyColor: ink,
          displayColor: ink,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: base,
      scaffoldBackgroundColor: bg,
      fontFamily: 'Segoe UI',
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: highContrast ? Colors.white : Colors.transparent,
        foregroundColor: ink,
        titleTextStyle: TextStyle(
          fontFamily: 'Segoe UI',
          fontSize: largeControls ? 20 : 18,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: highContrast ? Colors.black : AppColors.deepTeal.withValues(alpha: 0.06),
            width: highContrast ? 1.5 : 1,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: largeControls ? 18 : 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: highContrast ? Colors.black54 : AppColors.deepTeal.withValues(alpha: 0.12),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: highContrast ? Colors.black54 : AppColors.deepTeal.withValues(alpha: 0.12),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: Size(64, largeControls ? 56 : 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: largeControls ? 17 : 15,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: highContrast ? const Color(0xFF8B1E00) : AppColors.coral,
        foregroundColor: Colors.white,
        extendedSizeConstraints: BoxConstraints(
          minHeight: largeControls ? 56 : 48,
          minWidth: largeControls ? 120 : 80,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: highContrast
            ? primary.withValues(alpha: 0.2)
            : AppColors.mint.withValues(alpha: 0.18),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: largeControls ? 13 : 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        height: largeControls ? 76 : 68,
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(size: largeControls ? 28 : 24),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? primary : Colors.grey,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: highContrast ? const Color(0xFFEEEEEE) : AppColors.sand,
        selectedColor: primary.withValues(alpha: 0.22),
        labelStyle: TextStyle(
          color: ink,
          fontSize: largeControls ? 14 : 12,
          fontWeight: FontWeight.w600,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: largeControls ? 12 : 8,
          vertical: largeControls ? 10 : 6,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
