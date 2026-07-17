import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/meeting_invitation.dart';
import '../../domain/entities/meeting_request.dart';
import '../states/ea_dashboard_state.dart';
import 'glass_panel.dart';

class EaInvitationsList extends StatelessWidget {
  const EaInvitationsList({
    super.key,
    required this.invitations,
    required this.onAccept,
    required this.onDecline,
  });

  final List<MeetingInvitation> invitations;
  final ValueChanged<String> onAccept;
  final ValueChanged<String> onDecline;

  @override
  Widget build(BuildContext context) {
    if (invitations.isEmpty) {
      return const _EmptyHint(message: 'No pending invitations.');
    }

    return Column(
      children: [
        for (var i = 0; i < invitations.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invitations[i].title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'From ${invitations[i].fromName} · '
                    '${DateFormat('EEE, MMM d · h:mm a').format(invitations[i].scheduledAt.toLocal())}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (invitations[i].location != null)
                    Text(
                      invitations[i].location!,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      FilledButton.tonal(
                        onPressed: () => onAccept(invitations[i].id),
                        child: const Text('Accept'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      OutlinedButton(
                        onPressed: () => onDecline(invitations[i].id),
                        child: const Text('Decline'),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate(delay: (40 * i).ms).fadeIn().slideX(begin: 0.06, end: 0),
          ),
      ],
    );
  }
}

class EaRequestsList extends StatelessWidget {
  const EaRequestsList({
    super.key,
    required this.requests,
    required this.onApprove,
    required this.onReject,
  });

  final List<MeetingRequest> requests;
  final ValueChanged<String> onApprove;
  final ValueChanged<String> onReject;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const _EmptyHint(message: 'No pending meeting requests.');
    }

    return Column(
      children: [
        for (var i = 0; i < requests.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    requests[i].title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${requests[i].requesterName} · preferred '
                    '${DateFormat('EEE, MMM d · h:mm a').format(requests[i].preferredAt.toLocal())}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (requests[i].notes != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      requests[i].notes!,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      FilledButton(
                        onPressed: () => onApprove(requests[i].id),
                        child: const Text('Schedule'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      TextButton(
                        onPressed: () => onReject(requests[i].id),
                        child: const Text('Decline'),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate(delay: (40 * i).ms).fadeIn().slideX(begin: 0.06, end: 0),
          ),
      ],
    );
  }
}

class EaActivityList extends StatelessWidget {
  const EaActivityList({super.key, required this.items});

  final List<ActivityItem> items;

  IconData _icon(String key) => switch (key) {
    'check' => Icons.check_circle_outline_rounded,
    'mail' => Icons.mail_outline_rounded,
    'request' => Icons.pending_actions_rounded,
    'place' => Icons.place_outlined,
    _ => Icons.history_rounded,
  };

  Color _color(String key) => switch (key) {
    'check' => AppColors.success,
    'mail' => AppColors.info,
    'request' => AppColors.warning,
    'place' => AppColors.secondary,
    _ => AppColors.primary,
  };

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: _color(
                    items[i].icon,
                  ).withValues(alpha: 0.15),
                  child: Icon(
                    _icon(items[i].icon),
                    size: 16,
                    color: _color(items[i].icon),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        items[i].title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        items[i].subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        DateFormat(
                          'MMM d · h:mm a',
                        ).format(items[i].at.toLocal()),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ).animate(delay: (35 * i).ms).fadeIn().slideY(begin: 0.05, end: 0),
            if (i < items.length - 1) const Divider(height: AppSpacing.lg),
          ],
        ],
      ),
    );
  }
}

class EaQuickActions extends StatelessWidget {
  const EaQuickActions({
    super.key,
    required this.onCreateMeeting,
    required this.onOpenMeetings,
    required this.onOpenEmployees,
    required this.onOpenCompany,
  });

  final VoidCallback onCreateMeeting;
  final VoidCallback onOpenMeetings;
  final VoidCallback onOpenEmployees;
  final VoidCallback onOpenCompany;

  @override
  Widget build(BuildContext context) {
    final actions = <(IconData, String, Color, VoidCallback)>[
      (
        Icons.add_circle_outline_rounded,
        'Create Meeting',
        AppColors.primary,
        onCreateMeeting,
      ),
      (
        Icons.event_note_rounded,
        'All Meetings',
        AppColors.secondary,
        onOpenMeetings,
      ),
      (Icons.groups_outlined, 'Employees', AppColors.info, onOpenEmployees),
      (Icons.domain_rounded, 'Company', AppColors.accent, onOpenCompany),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 560;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (var i = 0; i < actions.length; i++)
              SizedBox(
                width: wide
                    ? (constraints.maxWidth - AppSpacing.sm) / 2
                    : constraints.maxWidth,
                child:
                    GlassPanel(
                          onTap: actions[i].$4,
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: actions[i].$3.withValues(alpha: 0.12),
                                  borderRadius: AppRadius.mdAll,
                                ),
                                child: Icon(
                                  actions[i].$1,
                                  color: actions[i].$3,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Text(
                                  actions[i].$2,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        )
                        .animate(delay: (40 * i).ms)
                        .fadeIn()
                        .scale(
                          begin: const Offset(0.96, 0.96),
                          end: const Offset(1, 1),
                        ),
              ),
          ],
        );
      },
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
