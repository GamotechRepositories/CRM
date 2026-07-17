import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../meetings/domain/entities/meeting.dart';
import 'glass_panel.dart';

class EaCompanyBanner extends StatelessWidget {
  const EaCompanyBanner({
    super.key,
    required this.companyName,
    required this.industry,
    required this.color,
    required this.employeeCount,
  });

  final String companyName;
  final String industry;
  final Color color;
  final int employeeCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GlassPanel(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Hero(
            tag: 'ea_company_banner',
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: AppRadius.lgAll,
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Icon(Icons.apartment_rounded, color: color, size: 28),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assigned company',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  companyName,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ).animate().fadeIn().slideX(begin: 0.06, end: 0),
                Text(
                  '$industry · $employeeCount people · locked to this org',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.lock_rounded, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class EaGreetingCard extends StatelessWidget {
  const EaGreetingCard({
    super.key,
    required this.name,
    required this.todayCount,
    required this.pendingCount,
  });

  final String name;
  final int todayCount;
  final int pendingCount;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final date = DateFormat('EEEE, MMMM d').format(DateTime.now());

    return GlassPanel(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            date.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              letterSpacing: 1.1,
              color: scheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '$_greeting, $name',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ).animate().fadeIn().slideY(begin: 0.1, end: 0),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Executive Assistant · $todayCount today · $pendingCount items need attention',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class EaMeetingTile extends StatelessWidget {
  const EaMeetingTile({
    super.key,
    required this.meeting,
    this.index = 0,
    this.onTap,
  });

  final Meeting meeting;
  final int index;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final time = DateFormat('h:mm a').format(meeting.scheduledAt.toLocal());
    final date = DateFormat('EEE, MMM d').format(meeting.scheduledAt.toLocal());

    return GlassPanel(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.55),
              borderRadius: AppRadius.mdAll,
            ),
            child: Icon(
              meeting.isTeamMeeting
                  ? Icons.groups_rounded
                  : Icons.event_available_rounded,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meeting.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '$time · $date',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (meeting.priority == MeetingPriority.high ||
              meeting.priority == MeetingPriority.critical)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: AppRadius.fullAll,
              ),
              child: Text(
                meeting.priority.label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    ).animate(delay: (45 * index).ms).fadeIn().slideY(begin: 0.08, end: 0);
  }
}

class EaSectionHeader extends StatelessWidget {
  const EaSectionHeader({
    super.key,
    required this.title,
    required this.count,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final int count;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

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
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: scheme.secondaryContainer.withValues(alpha: 0.7),
            borderRadius: AppRadius.fullAll,
          ),
          child: Text(
            '$count',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
