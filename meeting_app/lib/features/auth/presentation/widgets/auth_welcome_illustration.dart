import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_spacing.dart';

/// Large welcoming illustration for the login screen.
class AuthWelcomeIllustration extends StatelessWidget {
  const AuthWelcomeIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context).width.clamp(180.0, 280.0);

    return SizedBox(
      height: size * 0.85,
      width: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
                width: size * 0.9,
                height: size * 0.9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary.withValues(alpha: 0.08),
                ),
              )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(0.96, 0.96),
                end: const Offset(1.04, 1.04),
                duration: 2400.ms,
              ),
          Icon(
                Icons.calendar_month_rounded,
                size: size * 0.42,
                color: scheme.primary,
              )
              .animate()
              .fadeIn(duration: 600.ms)
              .slideY(begin: 0.12, end: 0, curve: Curves.easeOutCubic),
          Positioned(
            right: size * 0.08,
            top: size * 0.18,
            child: Icon(
              Icons.videocam_rounded,
              size: size * 0.16,
              color: scheme.tertiary,
            ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.3, end: 0),
          ),
          Positioned(
            left: size * 0.1,
            bottom: size * 0.2,
            child: Icon(
              Icons.handshake_rounded,
              size: size * 0.14,
              color: scheme.secondary,
            ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.3, end: 0),
          ),
        ],
      ),
    );
  }
}

class AuthScreenHeader extends StatelessWidget {
  const AuthScreenHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
