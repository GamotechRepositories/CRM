import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
  });

  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark
          ? AppColors.skeletonBaseDark
          : AppColors.skeletonBaseLight,
      highlightColor: isDark
          ? AppColors.skeletonHighlightDark
          : AppColors.skeletonHighlightLight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.skeletonBaseDark
              : AppColors.skeletonBaseLight,
          borderRadius: borderRadius ?? AppRadius.smAll,
        ),
      ),
    );
  }
}

class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SkeletonBox(
          width: 48,
          height: 48,
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: double.infinity, height: 14),
              SizedBox(height: 8),
              SkeletonBox(width: 120, height: 12),
            ],
          ),
        ),
      ],
    );
  }
}

class SkeletonLoader extends StatelessWidget {
  const SkeletonLoader({
    super.key,
    this.itemCount = 5,
    this.padding = const EdgeInsets.all(16),
  });

  final int itemCount;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading content',
      child: ListView.separated(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) => const SkeletonListTile(),
      ),
    );
  }
}
