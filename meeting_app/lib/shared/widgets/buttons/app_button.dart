import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_spacing.dart';

enum AppButtonVariant { primary, secondary, outlined, ghost, destructive }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.isExpanded = false,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool isExpanded;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final child = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: variant == AppButtonVariant.primary
                  ? colorScheme.onPrimary
                  : colorScheme.primary,
            ),
          )
        : Row(
            mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(label),
            ],
          );

    final button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: isLoading ? null : onPressed,
        child: child,
      ),
      AppButtonVariant.secondary => FilledButton.tonal(
        onPressed: isLoading ? null : onPressed,
        child: child,
      ),
      AppButtonVariant.outlined => OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        child: child,
      ),
      AppButtonVariant.ghost => TextButton(
        onPressed: isLoading ? null : onPressed,
        child: child,
      ),
      AppButtonVariant.destructive => FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.error,
          foregroundColor: colorScheme.onError,
        ),
        child: child,
      ),
    };

    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      enabled: onPressed != null && !isLoading,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppConstants.minTouchTarget,
        ),
        child: isExpanded
            ? SizedBox(width: double.infinity, child: button)
            : button,
      ),
    );
  }
}
