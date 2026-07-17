import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../states/boss_dashboard_state.dart';
import 'glass_panel.dart';

class TodayScheduleRail extends StatelessWidget {
  const TodayScheduleRail({super.key, required this.meetings});

  final List<PortfolioMeeting> meetings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (meetings.isEmpty) {
      return GlassPanel(
        child: Row(
          children: [
            Icon(Icons.event_busy_rounded, color: scheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'No meetings scheduled for today in this view.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: meetings.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final item = meetings[index];
          final time = DateFormat('h:mm a').format(item.scheduledAt.toLocal());
          return SizedBox(
                width: 200,
                child: GlassPanel(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        time,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: item.companyColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        item.chipLabel,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .animate(delay: (40 * index).ms)
              .fadeIn()
              .slideX(begin: 0.08, end: 0);
        },
      ),
    );
  }
}
