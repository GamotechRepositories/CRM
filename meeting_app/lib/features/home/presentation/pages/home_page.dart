import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/layout/app_scaffold.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      maxContentWidth: 960,
      appBar: AppBar(title: const Text(AppConstants.appName)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, Executive',
                  style: context.textTheme.headlineSmall,
                ).animate().fadeIn().slideY(begin: 0.05),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Your enterprise meeting management foundation is ready. '
                  'Explore the design system and configure preferences before '
                  'building features.',
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Explore Design System',
                  icon: Icons.palette_outlined,
                  onPressed: () => context.go(RoutePaths.foundation),
                ).animate().fadeIn(delay: 200.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
