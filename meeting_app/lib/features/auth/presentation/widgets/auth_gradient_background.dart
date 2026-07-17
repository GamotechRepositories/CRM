import 'package:flutter/material.dart';

/// Soft gradient backdrop for auth flows (light + dark aware).
class AuthGradientBackground extends StatelessWidget {
  const AuthGradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF0B1120),
                  scheme.primary.withValues(alpha: 0.35),
                  const Color(0xFF111827),
                ]
              : [
                  const Color(0xFFEFF6FF),
                  scheme.primary.withValues(alpha: 0.18),
                  const Color(0xFFF8FAFC),
                ],
          stops: const [0.0, 0.45, 1.0],
        ),
      ),
      child: child,
    );
  }
}
