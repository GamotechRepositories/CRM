import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../states/boss_dashboard_state.dart';
import 'glass_panel.dart';

class MeetingTimeline extends StatelessWidget {
  const MeetingTimeline({super.key, required this.meetings});

  final List<PortfolioMeeting> meetings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (meetings.isEmpty) {
      return GlassPanel(
        child: Text(
          'No meetings in the selected scope.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    }

    final items = meetings.take(8).toList();

    return GlassPanel(
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _TimelineRow(
              item: items[i],
              isLast: i == items.length - 1,
            ).animate(delay: (45 * i).ms).fadeIn().slideX(begin: 0.04, end: 0),
          ],
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.item, required this.isLast});

  final PortfolioMeeting item;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final time = DateFormat(
      'MMM d · h:mm a',
    ).format(item.scheduledAt.toLocal());

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 18,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: item.companyColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: item.companyColor.withValues(alpha: 0.4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: scheme.outline.withValues(alpha: 0.35),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.chipLabel} · $time',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
