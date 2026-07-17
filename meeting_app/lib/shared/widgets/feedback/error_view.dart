import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/error/failures.dart';
import '../../../core/theme/app_spacing.dart';
import '../buttons/app_button.dart';

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.failure, this.onRetry});

  final Failure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: 'Error: ${failure.message}',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final content = Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 56, color: colorScheme.error)
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .scale(begin: const Offset(0.8, 0.8)),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Something went wrong',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  failure.message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 200.ms),
                if (onRetry != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'Try Again',
                    icon: Icons.refresh,
                    onPressed: onRetry,
                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),
                ],
              ],
            ),
          );

          return Center(
            child: constraints.hasBoundedHeight
                ? SingleChildScrollView(child: content)
                : content,
          );
        },
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: '$title. ${message ?? ''}',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final content = Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 64,
                  color: colorScheme.outline,
                ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),
                const SizedBox(height: AppSpacing.md),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ).animate().fadeIn(delay: 100.ms),
                if (message != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    message!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 200.ms),
                ],
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: actionLabel!,
                    onPressed: onAction,
                  ).animate().fadeIn(delay: 300.ms),
                ],
              ],
            ),
          );

          return Center(
            child: constraints.hasBoundedHeight
                ? SingleChildScrollView(child: content)
                : content,
          );
        },
      ),
    );
  }
}
