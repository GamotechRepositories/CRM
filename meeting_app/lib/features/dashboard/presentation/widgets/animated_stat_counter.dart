import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_spacing.dart';

class AnimatedStatCounter extends StatelessWidget {
  const AnimatedStatCounter({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.accent,
    this.delay = Duration.zero,
  });

  final int value;
  final String label;
  final IconData? icon;
  final Color? accent;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = accent ?? scheme.primary;

    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: color),
              const SizedBox(height: AppSpacing.xs),
            ],
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value.toDouble()),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, animated, _) {
                return Text(
                  animated.round().toString(),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: color,
                  ),
                );
              },
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        )
        .animate(delay: delay)
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic);
  }
}
