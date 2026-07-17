import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';

/// Minimal glass surface for executive dashboard panels.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.borderRadius,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = borderRadius ?? AppRadius.lgAll;

    final panel = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            color: scheme.surface.withValues(alpha: isDark ? 0.55 : 0.72),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.surface.withValues(alpha: isDark ? 0.65 : 0.85),
                scheme.surfaceContainerHighest.withValues(
                  alpha: isDark ? 0.35 : 0.55,
                ),
              ],
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );

    return panel;
  }
}
