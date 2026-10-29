import 'package:flutter/material.dart';

class AppColors {
  static const navy = Color(0xFF0B1437);
  static const primary = Color(0xFF4054D6);
  static const accent = Color(0xFF15AABF);
  static const rose = Color(0xFFE64980);
  static const violet = Color(0xFF7950F2);
  static const amber = Color(0xFFF59F00);
  static const surfaceAlt = Color(0xFFEDF0FA);
  static const background = Color(0xFFF5F7FC);
  static const ink = Color(0xFF111833);
  static const muted = Color(0xFF586079);
  static const success = Color(0xFF0B7A55);
  static const warning = Color(0xFFB35C00);
  static const danger = Color(0xFFC92A2A);

  static const heroGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFF0B1437), Color(0xFF2B3BA8), Color(0xFF5B3CC4)],
  );
}

class AppTheme {
  static const fontFamily = 'PlexArabic';

  static ThemeData light({bool highContrast = false, bool largeControls = false}) {
    final primary = highContrast ? const Color(0xFF1A237E) : AppColors.primary;
    final bg = highContrast ? Colors.white : AppColors.background;
    final ink = highContrast ? Colors.black : AppColors.ink;
    final border = highContrast ? Colors.black : AppColors.navy.withValues(alpha: 0.07);
    final base = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      secondary: highContrast ? const Color(0xFF8B0036) : AppColors.rose,
      surface: bg,
      onPrimary: Colors.white,
      onSurface: ink,
    );

    final textTheme = ThemeData(useMaterial3: true, brightness: Brightness.light)
        .textTheme
        .apply(
          fontFamily: fontFamily,
          bodyColor: ink,
          displayColor: ink,
        );

    final radius = BorderRadius.circular(16);

    return ThemeData(
      useMaterial3: true,
      colorScheme: base,
      scaffoldBackgroundColor: bg,
      fontFamily: fontFamily,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: bg,
        foregroundColor: ink,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: largeControls ? 22 : 19,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: Size.square(largeControls ? 52 : 44),
          iconSize: largeControls ? 28 : 24,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: border, width: highContrast ? 1.5 : 1),
        ),
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: largeControls ? 14 : 10,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: largeControls ? 17 : 15,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 18,
          vertical: largeControls ? 18 : 14,
        ),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: highContrast ? Colors.black54 : AppColors.navy.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: highContrast ? Colors.black54 : AppColors.navy.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: primary, width: 2.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: Size(64, largeControls ? 58 : 48),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: largeControls ? 17 : 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size(64, largeControls ? 54 : 46),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: largeControls ? 16 : 14,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: highContrast ? const Color(0xFF8B0036) : AppColors.rose,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        extendedSizeConstraints: BoxConstraints(
          minHeight: largeControls ? 58 : 48,
          minWidth: largeControls ? 120 : 80,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : Colors.grey.shade600,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? primary : Colors.grey.shade300,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        thumbColor: primary,
        trackHeight: largeControls ? 8 : 5,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: highContrast ? const Color(0xFFEEEEEE) : AppColors.surfaceAlt,
        selectedColor: primary.withValues(alpha: 0.18),
        side: BorderSide(color: highContrast ? Colors.black45 : Colors.transparent),
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          color: ink,
          fontSize: largeControls ? 15 : 13,
          fontWeight: FontWeight.w600,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: largeControls ? 12 : 8,
          vertical: largeControls ? 10 : 6,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy,
        contentTextStyle: const TextStyle(fontFamily: fontFamily, color: Colors.white, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
      ),
    );
  }
}
