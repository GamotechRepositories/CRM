import 'package:flutter/material.dart';

/// Premium color palette for light and dark themes.
abstract final class AppColors {
  // Brand
  static const Color primary = Color(0xFF1D4ED8);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF1E3A8A);
  static const Color secondary = Color(0xFF0F766E);
  static const Color accent = Color(0xFFF59E0B);

  // Neutrals — Light
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceContainerLight = Color(0xFFF1F5F9);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);

  // Neutrals — Dark
  static const Color backgroundDark = Color(0xFF0B1120);
  static const Color surfaceDark = Color(0xFF111827);
  static const Color surfaceContainerDark = Color(0xFF1E293B);
  static const Color borderDark = Color(0xFF334155);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  // Semantic
  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF0284C7);

  // Skeleton shimmer
  static const Color skeletonBaseLight = Color(0xFFE2E8F0);
  static const Color skeletonHighlightLight = Color(0xFFF8FAFC);
  static const Color skeletonBaseDark = Color(0xFF1E293B);
  static const Color skeletonHighlightDark = Color(0xFF334155);
}
