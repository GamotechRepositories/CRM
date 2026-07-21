import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/meeting.dart';

Color meetingPriorityColor(MeetingPriority priority) => switch (priority) {
  MeetingPriority.low => AppColors.info,
  MeetingPriority.medium => AppColors.secondary,
  MeetingPriority.high => AppColors.warning,
  MeetingPriority.critical => AppColors.error,
};

Color meetingStatusColor(MeetingStatus status) => switch (status) {
  MeetingStatus.scheduled => AppColors.primary,
  MeetingStatus.ongoing => AppColors.success,
  MeetingStatus.completed => AppColors.textSecondaryLight,
  MeetingStatus.cancelled => AppColors.error,
  MeetingStatus.rescheduled => AppColors.warning,
  MeetingStatus.missed => AppColors.error,
};

class MeetingTag extends StatelessWidget {
  const MeetingTag({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.fullAll,
      ),
      child: Text(
        label,
        style: context.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class MeetingEmptyState extends StatelessWidget {
  const MeetingEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: scheme.primary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Clear meeting row used on Home and Meetings list.
class MeetingListCard extends StatelessWidget {
  const MeetingListCard({
    super.key,
    required this.meeting,
    this.showOrganizer = true,
    this.canEdit = false,
    this.onEdit,
  });

  final Meeting meeting;
  final bool showOrganizer;
  final bool canEdit;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final start = meeting.startAt.toLocal();
    final end = meeting.endAt.toLocal();
    final isToday = DateUtils.isSameDay(start, DateTime.now());

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.lgAll,
        onTap: () => context.push(RoutePaths.meetingDetailsPath(meeting.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.08),
                  borderRadius: AppRadius.mdAll,
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat('MMM').format(start).toUpperCase(),
                      style: context.textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${start.day}',
                      style: context.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      ),
                    ),
                    Text(
                      DateFormat('EEE').format(start),
                      style: context.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (isToday)
                          MeetingTag(label: 'Today', color: AppColors.success),
                        MeetingTag(
                          label: meeting.status.label,
                          color: meetingStatusColor(meeting.status),
                        ),
                        if (meeting.priority == MeetingPriority.high ||
                            meeting.priority == MeetingPriority.critical)
                          MeetingTag(
                            label: meeting.priority.label,
                            color: meetingPriorityColor(meeting.priority),
                          ),
                        if (meeting.bossMarkedImportant)
                          MeetingTag(
                            label: 'Important',
                            color: AppColors.warning,
                          ),
                        if (meeting.coordinatorApproval ==
                            CoordinatorApproval.pending)
                          MeetingTag(
                            label: 'Waiting for approval',
                            color: AppColors.warning,
                          ),
                        if (meeting.coordinatorApproval ==
                            CoordinatorApproval.approved)
                          MeetingTag(
                            label: 'Approved',
                            color: AppColors.success,
                          ),
                        if (meeting.coordinatorApproval ==
                            CoordinatorApproval.rejected)
                          MeetingTag(
                            label: 'Rejected',
                            color: AppColors.error,
                          ),
                        if (meeting.rescheduleRequested)
                          MeetingTag(
                            label: 'Reschedule',
                            color: AppColors.warning,
                          ),
                        if (meeting.bossResponse == InvitationResponse.accepted)
                          MeetingTag(
                            label: 'Boss attending',
                            color: AppColors.success,
                          ),
                        if (meeting.bossResponse == InvitationResponse.declined)
                          MeetingTag(
                            label: 'Boss declined',
                            color: AppColors.error,
                          ),
                        if (meeting.bossResponse == InvitationResponse.pending &&
                            showOrganizer)
                          MeetingTag(
                            label: 'Awaiting Boss',
                            color: AppColors.info,
                          ),
                      ],
                    ).animate().fadeIn(duration: 220.ms),
                    const SizedBox(height: 8),
                    Text(
                      meeting.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${DateFormat('h:mm a').format(start)} – ${DateFormat('h:mm a').format(end)}'
                      '${showOrganizer ? ' · ${meeting.organizerName}${meeting.organizerRoleOrEmpty.trim().isNotEmpty ? ' (${meeting.organizerRoleOrEmpty})' : ''}' : ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (meeting.location?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.place_outlined,
                            size: 14,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              meeting.location ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (canEdit && onEdit != null)
                IconButton(
                  tooltip: 'Edit',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 240.ms).slideX(begin: 0.02, end: 0);
  }
}

class MeetingSectionHeader extends StatelessWidget {
  const MeetingSectionHeader({
    super.key,
    required this.title,
    this.trailing,
  });

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        for (final item in [trailing].whereType<Widget>()) item,
      ],
    );
  }
}
