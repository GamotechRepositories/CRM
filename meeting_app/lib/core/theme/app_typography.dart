import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typography system built on Inter with Material 3 text roles.
abstract final class AppTypography {
  static TextTheme textTheme(Brightness brightness) {
    final base = GoogleFonts.interTextTheme(
      brightness == Brightness.light
          ? ThemeData.light().textTheme
          : ThemeData.dark().textTheme,
    );

    final primaryColor = brightness == Brightness.light
        ? AppColors.textPrimaryLight
        : AppColors.textPrimaryDark;

    final secondaryColor = brightness == Brightness.light
        ? AppColors.textSecondaryLight
        : AppColors.textSecondaryDark;

    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
        color: primaryColor,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        color: primaryColor,
      ),
      displaySmall: base.displaySmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        color: primaryColor,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: primaryColor,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: primaryColor,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: primaryColor,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: primaryColor,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontWeight: FontWeight.w500,
        color: primaryColor,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontWeight: FontWeight.w500,
        color: primaryColor,
      ),
      bodyLarge: base.bodyLarge?.copyWith(color: primaryColor),
      bodyMedium: base.bodyMedium?.copyWith(color: primaryColor),
      bodySmall: base.bodySmall?.copyWith(color: secondaryColor),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontWeight: FontWeight.w500,
        color: secondaryColor,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontWeight: FontWeight.w500,
        color: secondaryColor,
        letterSpacing: 0.4,
      ),
    );
  }
}
