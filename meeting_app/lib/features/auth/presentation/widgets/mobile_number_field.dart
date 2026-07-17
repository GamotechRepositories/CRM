import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';

/// Reusable mobile number input with +91 prefix.
class MobileNumberField extends StatelessWidget {
  const MobileNumberField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.enabled = true,
    this.errorText,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final String? errorText;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: 'Mobile number',
      textField: true,
      child: TextField(
        controller: controller,
        enabled: enabled,
        autofocus: autofocus,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.done,
        style: Theme.of(context).textTheme.titleMedium,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ],
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: 'Mobile Number',
          hintText: '9876543210',
          errorText: errorText,
          prefixIcon: Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '+91',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  width: 1,
                  height: 24,
                  color: scheme.outline.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
          filled: true,
          border: OutlineInputBorder(borderRadius: AppRadius.lgAll),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.lgAll,
            borderSide: BorderSide(
              color: scheme.outline.withValues(alpha: 0.4),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.lgAll,
            borderSide: BorderSide(color: scheme.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: AppRadius.lgAll,
            borderSide: BorderSide(color: scheme.error),
          ),
        ),
      ),
    );
  }
}

/// Full-width primary CTA used on auth screens.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.enabled = true,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool enabled;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final canTap = enabled && !isLoading && onPressed != null;
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      enabled: canTap,
      label: label,
      child: SizedBox(
        width: double.infinity,
        height: AppConstants.minTouchTarget + 4,
        child: FilledButton(
          onPressed: canTap ? onPressed : null,
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
          ),
          child: isLoading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: scheme.onPrimary,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Text(label),
                  ],
                ),
        ),
      ),
    );
  }
}
