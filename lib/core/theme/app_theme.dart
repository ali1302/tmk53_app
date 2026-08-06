import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme_provider.dart';

class TmkPalette {
  const TmkPalette({
    required this.id,
    required this.primary,
    required this.primaryDeep,
    required this.accent,
    required this.cream,
  });

  final TmkThemeId id;
  final Color primary;
  final Color primaryDeep;
  final Color accent;
  final Color cream;

  static const maroon = TmkPalette(
    id: TmkThemeId.maroon,
    primary: Color(0xFF3D1035),
    primaryDeep: Color(0xFF2A0E24),
    accent: Color(0xFFC8982A),
    cream: Color(0xFFF5EFD8),
  );

  static const dark = TmkPalette(
    id: TmkThemeId.dark,
    primary: Color(0xFF1A1A2E),
    primaryDeep: Color(0xFF12121F),
    accent: Color(0xFFC8982A),
    cream: Color(0xFFE8E8F0),
  );

  static const teal = TmkPalette(
    id: TmkThemeId.teal,
    primary: Color(0xFF2E7D7D),
    primaryDeep: Color(0xFF1F5858),
    accent: Color(0xFFC8982A),
    cream: Color(0xFFE6F3F3),
  );

  static TmkPalette of(TmkThemeId id) {
    switch (id) {
      case TmkThemeId.dark:
        return dark;
      case TmkThemeId.teal:
        return teal;
      case TmkThemeId.maroon:
        return maroon;
    }
  }
}

/// Brand colors. Primary/deep/cream follow the Menu color theme.
class AppColors {
  AppColors._();

  static TmkPalette _palette = TmkPalette.maroon;

  static void bind(TmkPalette palette) => _palette = palette;

  static Color get primary => _palette.primary;
  static Color get primaryDeep => _palette.primaryDeep;
  static const Color accent = Color(0xFFC8982A);
  static Color get cream => _palette.cream;

  static const Color background = Color(0xFFF5F5F5);
  static const Color card = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF1A1A1A);
  static const Color muted = Color(0xFF7A6A50);
  static const Color gray500 = Color(0xFF6B7280);
  static const Color gray400 = Color(0xFF9CA3AF);
  static const Color success = Color(0xFF2ECC71);
  static const Color hijriGreen = Color(0xFF2E8B57);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light => fromPalette(TmkPalette.maroon);

  static ThemeData fromPalette(TmkPalette palette) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: palette.primary,
        primary: palette.primary,
        secondary: palette.accent,
        surface: AppColors.card,
        brightness: Brightness.light,
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.primary,
        foregroundColor: palette.accent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: palette.accent,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.accent, width: 1.5),
        ),
      ),
    );
  }
}
