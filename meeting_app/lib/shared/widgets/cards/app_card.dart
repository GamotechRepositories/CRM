import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final card = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgAll,
        child: Padding(padding: padding, child: child),
      ),
    );

    if (semanticLabel != null) {
      return Semantics(
        label: semanticLabel,
        button: onTap != null,
        child: card,
      );
    }
    return card;
  }
}
