import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import 'lottie_loading.dart';

class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
  });

  final bool isLoading;
  final Widget child;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: ColoredBox(
              color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.4),
              child: LottieLoading(message: message),
            ),
          ),
      ],
    );
  }
}

class FullScreenLoading extends StatelessWidget {
  const FullScreenLoading({super.key, this.message = 'Loading…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: LottieLoading(message: message),
      ),
    );
  }
}
