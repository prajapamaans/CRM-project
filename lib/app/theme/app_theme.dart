import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  static const primaryTeal = Color(0xFF00A884);
  static const primaryTealDark = Color(0xFF0F766E);
  static const accentPurple = Color(0xFF8B5CF6);
  static const purpleLightBg = Color(0xFFF3E8FF);

  static const textPrimary = Color(0xFF1F2937);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted = Color(0xFF9CA3AF);

  static const background = Color(0xFFF8FAFC);
  static const cardBackground = Color(0xFFFFFFFF);
  static const cardBorder = Color(0xFFE5E7EB);

  static const badgeTealBg = Color(0xFFD1FAE5);
  static const badgeTealText = Color(0xFF059669);

  static const badgeYellowBg = Color(0xFFFEF3C7);
  static const badgeYellowText = Color(0xFFD97706);

  static const badgeRedBg = Color(0xFFFEE2E2);
  static const badgeRedText = Color(0xFFDC2626);

  static const badgeBlueBg = Color(0xFFE0F2FE);
  static const badgeBlueText = Color(0xFF2563EB);

  static const iconGray = Color(0xFF6B7280);
}

class AppSpacing {
  AppSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

class AppTextStyles {
  AppTextStyles._();

  static TextStyle headingLarge = GoogleFonts.poppins(
    fontSize: 36,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  static TextStyle headingMedium = GoogleFonts.poppins(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle headingSmall = GoogleFonts.poppins(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle labelSmall = GoogleFonts.poppins(
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    color: AppColors.textMuted,
  );

  static TextStyle bodyMedium = GoogleFonts.poppins(
    fontSize: 15.5,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static TextStyle bodySmall = GoogleFonts.poppins(
    fontSize: 13.5,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => getThemeWithFontSize(16.0);

  static ThemeData getThemeWithFontSize(double baseFontSize) {
    final scale = baseFontSize / 16.0;
    final baseTextTheme = GoogleFonts.poppinsTextTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryTeal,
        primary: AppColors.primaryTeal,
        surface: AppColors.background,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      textTheme: baseTextTheme.copyWith(
        bodyLarge: GoogleFonts.poppins(fontSize: 16 * scale),
        bodyMedium: GoogleFonts.poppins(fontSize: 15 * scale),
        bodySmall: GoogleFonts.poppins(fontSize: 13.5 * scale),
        titleLarge: GoogleFonts.poppins(fontSize: 22 * scale, fontWeight: FontWeight.bold),
        titleMedium: GoogleFonts.poppins(fontSize: 18 * scale, fontWeight: FontWeight.w600),
        titleSmall: GoogleFonts.poppins(fontSize: 15 * scale, fontWeight: FontWeight.w600),
        displayLarge: GoogleFonts.poppins(fontSize: 57 * scale, fontWeight: FontWeight.bold),
        displayMedium: GoogleFonts.poppins(fontSize: 45 * scale, fontWeight: FontWeight.bold),
        displaySmall: GoogleFonts.poppins(fontSize: 36 * scale, fontWeight: FontWeight.bold),
        headlineLarge: GoogleFonts.poppins(fontSize: 32 * scale, fontWeight: FontWeight.w600),
        headlineMedium: GoogleFonts.poppins(fontSize: 28 * scale, fontWeight: FontWeight.w600),
        headlineSmall: GoogleFonts.poppins(fontSize: 24 * scale, fontWeight: FontWeight.w600),
        labelLarge: GoogleFonts.poppins(fontSize: 14 * scale, fontWeight: FontWeight.w600),
        labelMedium: GoogleFonts.poppins(fontSize: 12 * scale, fontWeight: FontWeight.w500),
        labelSmall: GoogleFonts.poppins(fontSize: 11 * scale, fontWeight: FontWeight.w500),
      ),
    );
  }
}
