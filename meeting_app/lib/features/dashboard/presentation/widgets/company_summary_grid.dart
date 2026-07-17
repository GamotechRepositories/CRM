import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../states/boss_dashboard_state.dart';
import 'glass_panel.dart';

class CompanySummaryGrid extends StatelessWidget {
  const CompanySummaryGrid({super.key, required this.items});

  final List<CompanySummaryItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final crossAxisCount = wide ? 3 : (constraints.maxWidth >= 480 ? 2 : 1);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: wide ? 1.55 : 1.7,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return GlassPanel(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: item.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              item.chipLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        '${item.meetingCount}',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: item.color,
                            ),
                      ),
                      Text(
                        'meetings · ${item.todayCount} today',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      if (item.highPriorityCount > 0) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: item.color.withValues(alpha: 0.12),
                            borderRadius: AppRadius.fullAll,
                          ),
                          child: Text(
                            '${item.highPriorityCount} high priority',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: item.color,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),
                )
                .animate(delay: (50 * index).ms)
                .fadeIn()
                .scale(
                  begin: const Offset(0.96, 0.96),
                  end: const Offset(1, 1),
                );
          },
        );
      },
    );
  }
}
