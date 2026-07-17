import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/rbac/app_permission.dart';
import '../../../../core/rbac/rbac_providers.dart';
import '../../../../core/rbac/widgets/permission_gate.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/layout/app_scaffold.dart';
import '../../../../shared/widgets/loading/skeleton_loader.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../meetings/domain/entities/meeting.dart';
import '../../../meetings/presentation/providers/meeting_providers.dart';
import '../../../meetings/presentation/widgets/meeting_ui.dart';
import '../providers/boss_dashboard_providers.dart';
import '../providers/ea_dashboard_providers.dart';

/// Home: Boss views schedule; Team creates meetings for Boss.
class SimpleMeetingDashboard extends ConsumerWidget {
  const SimpleMeetingDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(permissionSetProvider);
    final isBoss = !permissions.canCreateMeeting;
    if (isBoss) return const _BossHomeView();
    return const _TeamHomeView();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Boss home
// ─────────────────────────────────────────────────────────────────────────────

class _BossHomeView extends ConsumerWidget {
  const _BossHomeView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authSessionProvider).session?.user;
    final meetingsState = ref.watch(meetingsControllerProvider);
    final name = user?.displayName?.split(' ').first ?? 'Boss';
    final fullName = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : 'Boss';
    final now = DateTime.now();

    final sorted = [...meetingsState.meetings]
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final weekEnd = todayStart.add(const Duration(days: 7));

    final today = sorted
        .where(
          (m) =>
              !m.startAt.isBefore(todayStart) && m.startAt.isBefore(todayEnd),
        )
        .toList();
    final upcoming = sorted.where((m) => m.startAt.isAfter(now)).toList();
    final thisWeek = sorted
        .where(
          (m) =>
              !m.startAt.isBefore(todayStart) && m.startAt.isBefore(weekEnd),
        )
        .toList();
    final highPriority = sorted
        .where(
          (m) =>
              m.startAt.isAfter(now) &&
              (m.priority == MeetingPriority.high ||
                  m.priority == MeetingPriority.critical),
        )
        .length;
    final next = upcoming.isEmpty ? null : upcoming.first;
    final laterToday = today
        .where((m) => m.startAt.isAfter(now))
        .where((m) => next == null || m.id != next.id)
        .toList();
    final pastOrNowToday = today.where((m) => !m.startAt.isAfter(now)).toList();
    final restOfWeek = thisWeek
        .where((m) => !m.startAt.isBefore(todayEnd))
        .where((m) => next == null || m.id != next.id)
        .take(5)
        .toList();

    return AppScaffold(
      maxContentWidth: 800,
      padFloatingNav: true,
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        titleSpacing: AppSpacing.md,
        title: const Text('Home'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () =>
                ref.read(meetingsControllerProvider.notifier).load(null),
            icon: const Icon(Icons.refresh_rounded),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Text(
                fullName[0].toUpperCase(),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
      body: meetingsState.isLoading && meetingsState.meetings.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: SkeletonLoader(itemCount: 5),
            )
          : RefreshIndicator(
              onRefresh: () =>
                  ref.read(meetingsControllerProvider.notifier).load(null),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  4,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                children: [
                  if (meetingsState.errorMessage != null) ...[
                    _ErrorBanner(message: meetingsState.errorMessage!),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  _BossGreetingCard(
                    name: name,
                    greeting: _greeting(now),
                    freeUntil: next == null
                        ? 'Your day is clear'
                        : _freeUntilLabel(now, next.startAt.toLocal()),
                  ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.03, end: 0),
                  const SizedBox(height: AppSpacing.md),

                  _GlanceStatsBar(
                    items: [
                      _GlanceStat(
                        label: 'Today',
                        value: '${today.length}',
                        hint: today.isEmpty
                            ? 'Clear day'
                            : today.length == 1
                                ? '1 meeting'
                                : '${today.length} meetings',
                        color: AppColors.primary,
                        onTap: () => context.go(RoutePaths.meetings),
                      ),
                      _GlanceStat(
                        label: 'This week',
                        value: '${thisWeek.length}',
                        hint: thisWeek.isEmpty ? 'Nothing yet' : 'Next 7 days',
                        color: AppColors.secondary,
                        onTap: () => context.go(RoutePaths.meetings),
                      ),
                      _GlanceStat(
                        label: 'Priority',
                        value: '$highPriority',
                        hint: highPriority == 0
                            ? 'All calm'
                            : 'Needs focus',
                        color: AppColors.warning,
                        onTap: () => context.go(RoutePaths.meetings),
                      ),
                    ],
                  ).animate().fadeIn(delay: 70.ms).slideY(begin: 0.04, end: 0),
                  const SizedBox(height: AppSpacing.lg),

                  _SectionTitle(
                    title: 'Up next',
                    actionLabel: 'All meetings',
                    onAction: () => context.go(RoutePaths.meetings),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (next == null)
                    const _QuietDayCard(
                      title: 'No upcoming meetings',
                      message:
                          'Your schedule is clear. Your team will add meetings here.',
                    ).animate().fadeIn(delay: 90.ms)
                  else
                    _NextMeetingHero(meeting: next)
                        .animate()
                        .fadeIn(delay: 90.ms)
                        .slideY(begin: 0.05, end: 0),

                  const SizedBox(height: AppSpacing.lg),

                  _SectionTitle(
                    title: "Today's schedule",
                    count: laterToday.length,
                    actionLabel: 'All',
                    onAction: () => context.go(RoutePaths.meetings),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (today.isEmpty)
                    const _InlineEmpty(
                      icon: Icons.wb_sunny_outlined,
                      text: 'Nothing on the calendar for today.',
                    )
                  else if (laterToday.isEmpty)
                    _InlineEmpty(
                      icon: Icons.check_circle_outline_rounded,
                      text:
                          next != null &&
                              DateUtils.isSameDay(next.startAt.toLocal(), now)
                          ? 'Your next meeting is above — nothing else left today.'
                          : pastOrNowToday.isNotEmpty
                          ? 'All of today’s meetings are done.'
                          : 'Nothing remaining for today.',
                    )
                  else
                    ...laterToday.asMap().entries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _BossTimelineCard(meeting: e.value)
                            .animate()
                            .fadeIn(delay: (60 * e.key).ms)
                            .slideX(begin: 0.03, end: 0),
                      ),
                    ),

                  if (restOfWeek.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    _SectionTitle(
                      title: 'Coming this week',
                      count: restOfWeek.length,
                      actionLabel: 'See all',
                      onAction: () => context.go(RoutePaths.meetings),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ...restOfWeek.asMap().entries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _BossTimelineCard(
                          meeting: e.value,
                          compact: true,
                        ).animate().fadeIn(delay: (50 * e.key).ms),
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.md),
                  const _BossTipCard(
                    text:
                        'Tap any meeting for agenda, company, video link, and who scheduled it.',
                  ).animate().fadeIn(delay: 140.ms),
                ],
              ),
            ),
    );
  }

  String _greeting(DateTime now) {
    final h = now.hour;
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    return 'evening';
  }

  String _freeUntilLabel(DateTime now, DateTime nextStart) {
    final mins = nextStart.difference(now).inMinutes;
    if (mins <= 0) return 'Meeting starting now';
    if (mins < 60) return 'Free for $mins minutes';
    if (mins < 1440) {
      final h = mins ~/ 60;
      final m = mins % 60;
      return m == 0 ? 'Free for ${h}h' : 'Free for ${h}h ${m}m';
    }
    return 'Next: ${DateFormat('EEE, MMM d').format(nextStart)}';
  }
}

class _BossGreetingCard extends StatelessWidget {
  const _BossGreetingCard({
    required this.name,
    required this.greeting,
    required this.freeUntil,
  });

  final String name;
  final String greeting;
  final String freeUntil;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good $greeting, $name',
                  style: context.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        freeUntil,
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlanceStat {
  const _GlanceStat({
    required this.label,
    required this.value,
    required this.hint,
    required this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final String hint;
  final Color color;
  final VoidCallback? onTap;
}

/// Soft stats strip — Today / This week / Priority (no heavy boxes).
class _GlanceStatsBar extends StatelessWidget {
  const _GlanceStatsBar({required this.items});

  final List<_GlanceStat> items;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Colors.white.withValues(alpha: 0.72),
        borderRadius: AppRadius.xlAll,
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  indent: 8,
                  endIndent: 8,
                  color: Theme.of(context).dividerColor,
                ),
              Expanded(child: _GlanceStatCell(stat: items[i])),
            ],
          ],
        ),
      ),
    );
  }
}

class _GlanceStatCell extends StatelessWidget {
  const _GlanceStatCell({required this.stat});

  final _GlanceStat stat;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: stat.onTap,
        borderRadius: AppRadius.lgAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                stat.value,
                style: context.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: stat.color,
                  height: 1,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                stat.label,
                textAlign: TextAlign.center,
                style: context.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                stat.hint,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextMeetingHero extends StatelessWidget {
  const _NextMeetingHero({required this.meeting});

  final Meeting meeting;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final start = meeting.startAt.toLocal();
    final end = meeting.endAt.toLocal();
    final company = meeting.companyNameOrEmpty.trim().isNotEmpty
        ? meeting.companyNameOrEmpty.trim()
        : null;
    final mins = start.difference(DateTime.now()).inMinutes;
    final whenLabel = mins <= 0
        ? 'Starting now'
        : mins < 60
        ? 'In $mins min'
        : mins < 1440
        ? 'In ${(mins / 60).floor()}h ${mins % 60}m'
        : DateFormat('EEE, MMM d').format(start);
    final agenda = meeting.agenda.trim();
    final hasLink =
        meeting.meetLink != null && meeting.meetLink!.trim().isNotEmpty;
    final duration = end.difference(start);
    final durationLabel = duration.inHours > 0
        ? '${duration.inHours}h ${duration.inMinutes.remainder(60)}m'
        : '${duration.inMinutes} min';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.xlAll,
        onTap: () => context.push(RoutePaths.meetingDetailsPath(meeting.id)),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: AppRadius.xlAll,
            color: isDark ? null : const Color(0xFFEFF6FF),
            gradient: isDark
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.2),
                      AppColors.secondary.withValues(alpha: 0.14),
                      scheme.surface,
                    ],
                  )
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: AppRadius.fullAll,
                      ),
                      child: Text(
                        whenLabel,
                        style: context.textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      durationLabel,
                      style: context.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (meeting.priority == MeetingPriority.high ||
                        meeting.priority == MeetingPriority.critical)
                      MeetingTag(
                        label: meeting.priority.label,
                        color: meetingPriorityColor(meeting.priority),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  meeting.title,
                  style: context.textTheme.headlineSmall?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                if (agenda.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    agenda,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _HeroMeta(
                  icon: Icons.schedule_rounded,
                  text:
                      '${DateFormat('EEE, MMM d · h:mm a').format(start)} – ${DateFormat('h:mm a').format(end)}',
                ),
                const SizedBox(height: 6),
                _HeroMeta(
                  icon: Icons.person_outline_rounded,
                  text:
                      'By ${meeting.organizerName}${meeting.organizerRoleOrEmpty.isNotEmpty ? ' · ${meeting.organizerRoleOrEmpty}' : ''}',
                ),
                if (company != null) ...[
                  const SizedBox(height: 6),
                  _HeroMeta(icon: Icons.business_outlined, text: company),
                ],
                if (meeting.location != null &&
                    meeting.location!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _HeroMeta(
                    icon: Icons.place_outlined,
                    text: meeting.location!.trim(),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () =>
                        context.push(RoutePaths.meetingDetailsPath(meeting.id)),
                    icon: Icon(
                      hasLink
                          ? Icons.videocam_rounded
                          : Icons.arrow_forward_rounded,
                      size: 18,
                    ),
                    label: Text(hasLink ? 'Open meeting' : 'View details'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroMeta extends StatelessWidget {
  const _HeroMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _BossTimelineCard extends StatelessWidget {
  const _BossTimelineCard({required this.meeting, this.compact = false});

  final Meeting meeting;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final start = meeting.startAt.toLocal();
    final end = meeting.endAt.toLocal();
    final scheme = context.colorScheme;
    final company = meeting.companyNameOrEmpty.trim();
    final initial = meeting.organizerName.trim().isNotEmpty
        ? meeting.organizerName.trim()[0].toUpperCase()
        : '?';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.lgAll,
        onTap: () => context.push(RoutePaths.meetingDetailsPath(meeting.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: compact ? 56 : 72,
                decoration: BoxDecoration(
                  color: meetingPriorityColor(meeting.priority),
                  borderRadius: AppRadius.fullAll,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 54,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('h:mm').format(start),
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      DateFormat('a').format(start),
                      style: context.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('h:mm a').format(end),
                        style: context.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meeting.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.12,
                          ),
                          child: Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            [
                              if (!DateUtils.isSameDay(start, DateTime.now()))
                                DateFormat('EEE, MMM d').format(start),
                              meeting.organizerName,
                              if (company.isNotEmpty) company,
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          MeetingTag(
                            label: meeting.status.label,
                            color: meetingStatusColor(meeting.status),
                          ),
                          MeetingTag(
                            label: meeting.priority.label,
                            color: meetingPriorityColor(meeting.priority),
                          ),
                          if (meeting.meetLink != null &&
                              meeting.meetLink!.trim().isNotEmpty)
                            const MeetingTag(
                              label: 'Video',
                              color: AppColors.info,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    this.count,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final int? count;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Text(
                title,
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (count != null && count! > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: context.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: AppRadius.fullAll,
                  ),
                  child: Text(
                    '$count',
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _QuietDayCard extends StatelessWidget {
  const _QuietDayCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_available_rounded,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BossTipCard extends StatelessWidget {
  const _BossTipCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded, size: 18, color: AppColors.info),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: context.textTheme.bodySmall?.copyWith(
                color: AppColors.info,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Team home (kept simple + polished)
// ─────────────────────────────────────────────────────────────────────────────

class _TeamHomeView extends ConsumerWidget {
  const _TeamHomeView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authSessionProvider).session?.user;
    final meetingsState = ref.watch(meetingsControllerProvider);
    final name = user?.displayName?.split(' ').first ?? 'there';
    final scheme = context.colorScheme;

    final sorted = [...meetingsState.meetings]
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    final now = DateTime.now();
    final upcoming = sorted.where((m) => m.startAt.isAfter(now)).take(6).toList();
    final upcomingCount = sorted.where((m) => m.startAt.isAfter(now)).length;

    return AppScaffold(
      maxContentWidth: 800,
      padFloatingNav: true,
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        title: const Text('Home'),
      ),
      floatingActionButton: PermissionGate(
        permission: AppPermission.createMeeting,
        child: FloatingActionButton.extended(
          onPressed: () => context.push(RoutePaths.meetingCreate),
          icon: const Icon(Icons.add_rounded),
          label: const Text('New meeting'),
        ).animate().fadeIn().scale(begin: const Offset(0.92, 0.92)),
      ),
      body: meetingsState.isLoading && meetingsState.meetings.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: SkeletonLoader(itemCount: 4),
            )
          : RefreshIndicator(
              onRefresh: () =>
                  ref.read(meetingsControllerProvider.notifier).load(null),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.xlAll,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          scheme.primary,
                          scheme.primary.withValues(alpha: 0.85),
                          AppColors.secondary,
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Team',
                          style: context.textTheme.labelLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Hello, $name',
                          style: context.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Create clear meetings for the Boss — title, time, company, agenda.',
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn().slideY(begin: 0.05, end: 0),
                  const SizedBox(height: AppSpacing.lg),
                  _GlanceStatsBar(
                    items: [
                      _GlanceStat(
                        label: 'Upcoming',
                        value: '$upcomingCount',
                        hint: upcomingCount == 0
                            ? 'None scheduled'
                            : 'For the Boss',
                        color: AppColors.primary,
                        onTap: () => context.go(RoutePaths.meetings),
                      ),
                      _GlanceStat(
                        label: 'Total',
                        value: '${meetingsState.meetings.length}',
                        hint: 'All meetings',
                        color: AppColors.secondary,
                        onTap: () => context.go(RoutePaths.meetings),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  MeetingSectionHeader(
                    title: 'Next up',
                    trailing: TextButton(
                      onPressed: () => context.go(RoutePaths.meetings),
                      child: const Text('See all'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (upcoming.isEmpty)
                    MeetingEmptyState(
                      icon: Icons.event_available_rounded,
                      title: 'No meetings yet',
                      message: 'Tap New meeting to schedule one for the Boss.',
                      actionLabel: 'New meeting',
                      onAction: () => context.push(RoutePaths.meetingCreate),
                    )
                  else
                    ...upcoming.map(
                      (m) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: MeetingListCard(meeting: m, showOrganizer: false),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: AppRadius.lgAll,
      ),
      child: Text(
        message,
        style: context.textTheme.bodyMedium?.copyWith(color: AppColors.error),
      ),
    );
  }
}

final canViewStaffDashboardProvider = Provider<bool>((ref) {
  if (ref.watch(canViewBossDashboardProvider)) return false;
  if (ref.watch(canViewEaDashboardProvider)) return false;
  return ref.watch(permissionSetProvider).can(AppPermission.viewDashboard);
});
