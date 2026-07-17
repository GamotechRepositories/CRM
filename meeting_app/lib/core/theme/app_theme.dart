import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_constants.dart';
import 'app_colors.dart';
import 'app_radius.dart';
import 'app_typography.dart';

/// Material 3 theme configuration for light and dark modes.
abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final colorScheme = isLight ? _lightColorScheme : _darkColorScheme;
    final textTheme = AppTypography.textTheme(brightness);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: isLight
          ? AppColors.backgroundLight
          : AppColors.backgroundDark,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        systemOverlayStyle: isLight
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: BorderSide(
            color: isLight ? AppColors.borderLight : AppColors.borderDark,
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, AppConstants.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, AppConstants.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppConstants.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, AppConstants.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(
            color: isLight ? AppColors.borderLight : AppColors.borderDark,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(
            color: isLight ? AppColors.borderLight : AppColors.borderDark,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: colorScheme.error),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
        showDragHandle: true,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        indicatorShape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      dividerTheme: DividerThemeData(
        color: isLight ? AppColors.borderLight : AppColors.borderDark,
        thickness: 1,
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }

  static const ColorScheme _lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFDBEAFE),
    onPrimaryContainer: AppColors.primaryDark,
    secondary: AppColors.secondary,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFCCFBF1),
    onSecondaryContainer: Color(0xFF134E4A),
    tertiary: AppColors.accent,
    onTertiary: Color(0xFF451A03),
    tertiaryContainer: Color(0xFFFEF3C7),
    onTertiaryContainer: Color(0xFF78350F),
    error: AppColors.error,
    onError: Colors.white,
    surface: AppColors.surfaceLight,
    onSurface: AppColors.textPrimaryLight,
    onSurfaceVariant: AppColors.textSecondaryLight,
    outline: AppColors.borderLight,
    outlineVariant: Color(0xFFCBD5E1),
    shadow: Colors.black26,
    scrim: Colors.black54,
    inverseSurface: AppColors.textPrimaryLight,
    onInverseSurface: AppColors.surfaceLight,
    inversePrimary: AppColors.primaryLight,
    surfaceContainerHighest: AppColors.surfaceContainerLight,
  );

  static const ColorScheme _darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.primaryLight,
    onPrimary: Color(0xFF1E3A8A),
    primaryContainer: Color(0xFF1E40AF),
    onPrimaryContainer: Color(0xFFDBEAFE),
    secondary: Color(0xFF2DD4BF),
    onSecondary: Color(0xFF134E4A),
    secondaryContainer: Color(0xFF115E59),
    onSecondaryContainer: Color(0xFFCCFBF1),
    tertiary: AppColors.accent,
    onTertiary: Color(0xFF451A03),
    tertiaryContainer: Color(0xFF92400E),
    onTertiaryContainer: Color(0xFFFEF3C7),
    error: Color(0xFFF87171),
    onError: Color(0xFF7F1D1D),
    surface: AppColors.surfaceDark,
    onSurface: AppColors.textPrimaryDark,
    onSurfaceVariant: AppColors.textSecondaryDark,
    outline: AppColors.borderDark,
    outlineVariant: Color(0xFF475569),
    shadow: Colors.black54,
    scrim: Colors.black87,
    inverseSurface: AppColors.textPrimaryDark,
    onInverseSurface: AppColors.surfaceDark,
    inversePrimary: AppColors.primary,
    surfaceContainerHighest: AppColors.surfaceContainerDark,
  );
}
