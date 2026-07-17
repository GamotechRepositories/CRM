import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/responsive/responsive_layout.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/layout/app_scaffold.dart';
import '../../../../shared/widgets/loading/skeleton_loader.dart';

class FoundationPage extends ConsumerStatefulWidget {
  const FoundationPage({super.key});

  @override
  ConsumerState<FoundationPage> createState() => _FoundationPageState();
}

class _FoundationPageState extends ConsumerState<FoundationPage> {
  bool _showSkeleton = false;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      maxContentWidth: 960,
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            tooltip: 'Toggle skeleton preview',
            onPressed: () => setState(() => _showSkeleton = !_showSkeleton),
            icon: Icon(
              _showSkeleton ? Icons.visibility : Icons.view_agenda_outlined,
            ),
          ),
        ],
      ),
      body: ResponsiveLayout(
        mobile: _buildContent(context),
        tablet: _buildContent(context),
        desktop: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_showSkeleton) {
      return const SkeletonLoader();
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _SectionHeader(
          title: 'Foundation Ready',
          subtitle: 'Premium UI system for enterprise meeting management.',
        ).animate().fadeIn().slideY(begin: 0.05),
        const SizedBox(height: AppSpacing.lg),
        _buildTypographySection(context),
        const SizedBox(height: AppSpacing.lg),
        _buildButtonsSection(context),
        const SizedBox(height: AppSpacing.lg),
        _buildCardsSection(context),
        const SizedBox(height: AppSpacing.lg),
        _buildStatesSection(context),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  Widget _buildTypographySection(BuildContext context) {
    final textTheme = context.textTheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Typography', style: textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          Text('Display Medium', style: textTheme.displayMedium),
          Text('Headline Small', style: textTheme.headlineSmall),
          Text('Title Medium', style: textTheme.titleMedium),
          Text(
            'Body Medium — Inter typeface with Material 3 roles.',
            style: textTheme.bodyMedium,
          ),
          Text('Label Small', style: textTheme.labelSmall),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05);
  }

  Widget _buildButtonsSection(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Buttons', style: context.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AppButton(
                label: 'Primary',
                icon: Icons.add,
                onPressed: () => context.showAppSnackBar('Primary action'),
              ),
              AppButton(
                label: 'Secondary',
                variant: AppButtonVariant.secondary,
                onPressed: () {},
              ),
              AppButton(
                label: 'Outlined',
                variant: AppButtonVariant.outlined,
                onPressed: () {},
              ),
              AppButton(
                label: 'Ghost',
                variant: AppButtonVariant.ghost,
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05);
  }

  Widget _buildCardsSection(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Responsive Layout', style: context.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Current device: ${ResponsiveLayout.deviceTypeOf(context).name}',
            style: context.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Screen width: ${context.screenWidth.toStringAsFixed(0)}px',
            style: context.textTheme.bodySmall,
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.05);
  }

  Widget _buildStatesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Feedback States', style: context.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: ErrorView(
            failure: const NetworkFailure('Preview of error handling UI'),
            onRetry: () => context.showAppSnackBar('Retry tapped'),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 400.ms);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: context.textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: context.textTheme.bodyLarge?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
