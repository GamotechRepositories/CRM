import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../core/constants/asset_paths.dart';
import '../../../core/theme/app_spacing.dart';

class LottieLoading extends StatelessWidget {
  const LottieLoading({super.key, this.message, this.size = 120});

  final String? message;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: message ?? 'Loading',
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(
              AssetPaths.lottieLoading,
              width: size,
              height: size,
              fit: BoxFit.contain,
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                message!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
