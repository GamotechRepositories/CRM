import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Elevation and shadow tokens.
abstract final class AppShadows {
  static List<BoxShadow> sm(Brightness brightness) => [
    BoxShadow(
      color: brightness == Brightness.light
          ? Colors.black.withValues(alpha: 0.06)
          : Colors.black.withValues(alpha: 0.3),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> md(Brightness brightness) => [
    BoxShadow(
      color: brightness == Brightness.light
          ? Colors.black.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.4),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> lg(Brightness brightness) => [
    BoxShadow(
      color: brightness == Brightness.light
          ? AppColors.primary.withValues(alpha: 0.12)
          : Colors.black.withValues(alpha: 0.5),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
}
