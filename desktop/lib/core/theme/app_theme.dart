import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class AppTheme {
  // ── MODO OSCURO (Midnight Neon UI_titofy_3) ───────────────────────────────
  static ThemeData darkTheme([Color? primary]) {
    final accent = primary ?? AppColors.coral;
    final baseTextTheme = ThemeData.dark().textTheme;
    final outfitTextTheme = GoogleFonts.outfitTextTheme(baseTextTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: GoogleFonts.outfit().fontFamily,
      colorScheme: ColorScheme.dark(
        surface: AppColors.surface,
        primary: accent,
        secondary: AppColors.secondary,
        onPrimary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: outfitTextTheme.copyWith(
        displayLarge: GoogleFonts.outfit(
          fontSize: 36,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          letterSpacing: -1.0,
        ),
        headlineMedium: GoogleFonts.outfit(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.5,
        ),
        titleLarge: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleMedium: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
        bodyMedium: GoogleFonts.outfit(
          fontSize: 13,
          color: AppColors.textPrimary,
        ),
        bodySmall: GoogleFonts.outfit(
          fontSize: 11,
          color: AppColors.textMuted,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.glassBorder, width: 1),
        ),
      ),
    );
  }

  // ── MODO CLARO (Lavender Neo UI_titofy) ───────────────────────────────────
  static ThemeData lightTheme([Color? primary]) {
    final accent = primary ?? AppColors.coral;
    final baseTextTheme = ThemeData.light().textTheme;
    final outfitTextTheme = GoogleFonts.outfitTextTheme(baseTextTheme);

    const lightBg = Color(0xFFF6F5FB);
    const lightSurface = Color(0xFFFFFFFF);
    const lightTextPrimary = Color(0xFF1E1B4B);
    const lightTextSecondary = Color(0xFF6B7280);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      fontFamily: GoogleFonts.outfit().fontFamily,
      colorScheme: ColorScheme.light(
        surface: lightSurface,
        primary: accent,
        secondary: AppColors.secondary,
        onPrimary: Colors.white,
        onSurface: lightTextPrimary,
      ),
      textTheme: outfitTextTheme.copyWith(
        displayLarge: GoogleFonts.outfit(
          fontSize: 36,
          fontWeight: FontWeight.w800,
          color: lightTextPrimary,
          letterSpacing: -1.0,
        ),
        headlineMedium: GoogleFonts.outfit(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: lightTextPrimary,
          letterSpacing: -0.5,
        ),
        titleLarge: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: lightTextPrimary,
        ),
        titleMedium: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: lightTextSecondary,
        ),
        bodyMedium: GoogleFonts.outfit(
          fontSize: 13,
          color: lightTextPrimary,
        ),
        bodySmall: GoogleFonts.outfit(
          fontSize: 11,
          color: lightTextSecondary,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
    );
  }

  static ThemeData get dark => darkTheme(AppColors.coral);
  static ThemeData get light => lightTheme(AppColors.coral);
}
