import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_spacing.dart';

/// Shared brand mark used across splash → login (Hero).
class AuthHeroLogo extends StatelessWidget {
  const AuthHeroLogo({super.key, this.size = 88, this.showTitle = true});

  final double size;
  final bool showTitle;

  static const heroTag = 'auth_brand_logo';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Hero(
          tag: heroTag,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [scheme.primary, scheme.tertiary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                Icons.groups_rounded,
                size: size * 0.48,
                color: scheme.onPrimary,
              ),
            ),
          ),
        ),
        if (showTitle) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            AppConstants.appName,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.15, end: 0),
        ],
      ],
    );
  }
}
