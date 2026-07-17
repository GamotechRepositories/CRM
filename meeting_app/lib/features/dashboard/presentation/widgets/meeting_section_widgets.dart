import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../meetings/domain/entities/meeting.dart';
import '../states/boss_dashboard_state.dart';
import 'glass_panel.dart';

class MeetingSectionHeader extends StatelessWidget {
  const MeetingSectionHeader({
    super.key,
    required this.title,
    required this.count,
    this.subtitle,
    this.icon,
  });

  final String title;
  final int count;
  final String? subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.65),
            borderRadius: AppRadius.fullAll,
          ),
          child: Text(
            '$count',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onPrimaryContainer,
            ),
          ),
        ),
      ],
    );
  }
}

class PortfolioMeetingTile extends StatelessWidget {
  const PortfolioMeetingTile({
    super.key,
    required this.item,
    this.compact = false,
    this.index = 0,
  });

  final PortfolioMeeting item;
  final bool compact;
  final int index;

  Color _priorityColor(MeetingPriority priority) => switch (priority) {
    MeetingPriority.critical => AppColors.error,
    MeetingPriority.high => AppColors.error,
    MeetingPriority.medium => AppColors.warning,
    MeetingPriority.low => AppColors.info,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final time = DateFormat('h:mm a').format(item.scheduledAt.toLocal());
    final date = DateFormat('EEE, MMM d').format(item.scheduledAt.toLocal());

    return GlassPanel(
          padding: EdgeInsets.all(compact ? AppSpacing.sm + 4 : AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: 'boss_meeting_${item.id}',
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: item.companyColor.withValues(alpha: 0.15),
                      borderRadius: AppRadius.mdAll,
                      border: Border.all(
                        color: item.companyColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Icon(
                      item.isTeamMeeting
                          ? Icons.groups_rounded
                          : Icons.event_available_rounded,
                      color: item.companyColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$date · $time · ${item.chipLabel}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (item.priority == MeetingPriority.high ||
                        item.priority == MeetingPriority.critical) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _MetaChip(
                        label: item.priority.label,
                        color: _priorityColor(item.priority),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        )
        .animate(delay: (50 * index).ms)
        .fadeIn(duration: 380.ms)
        .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic);
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.fullAll,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
