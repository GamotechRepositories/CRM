import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/rbac/app_permission.dart';
import '../../../../core/rbac/permission_set.dart';
import '../../../../core/rbac/rbac_providers.dart';
import '../../../../core/rbac/widgets/permission_gate.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/layout/app_scaffold.dart';
import '../../../../shared/widgets/loading/loading_overlay.dart';
import '../../../../shared/widgets/loading/skeleton_loader.dart';
import '../../domain/entities/meeting.dart';
import '../providers/meeting_providers.dart';
import '../states/meetings_state.dart';
import '../widgets/meeting_ui.dart';

enum _MeetingFilter { all, today, upcoming, priority }

class MeetingsPage extends ConsumerStatefulWidget {
  const MeetingsPage({super.key});

  @override
  ConsumerState<MeetingsPage> createState() => _MeetingsPageState();
}

class _MeetingsPageState extends ConsumerState<MeetingsPage> {
  _MeetingFilter _filter = _MeetingFilter.all;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(meetingsControllerProvider);
    final permissions = ref.watch(permissionSetProvider);
    final userId = ref.watch(currentUserIdProvider);
    final isBoss = !permissions.canCreateMeeting;
    final stats = _MeetingStats.from(state.meetings);

    return AppScaffold(
      maxContentWidth: 960,
      padFloatingNav: true,
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        title: Text(
          isBoss ? 'Your meetings' : 'Meetings for Boss',
          style: context.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      floatingActionButton: PermissionGate(
        permission: AppPermission.createMeeting,
        child: FloatingActionButton.extended(
          onPressed: () => context.push(RoutePaths.meetingCreate),
          icon: const Icon(Icons.add_rounded),
          label: const Text('New meeting'),
        ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),
      ),
      body: LoadingOverlay(
        isLoading: state.isMutating,
        message: 'Working…',
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isBoss)
                    _BossMeetingsHeader(
                      total: stats.total,
                      upcoming: stats.upcoming,
                    )
                  else
                    Text(
                      'Meetings you create appear on the Boss schedule.',
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  _StatsRow(stats: stats),
                  if (stats.nextMeeting != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    _NextMeetingBanner(
                      meeting: stats.nextMeeting!,
                      isBoss: isBoss,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<_MeetingFilter>(
                      segments: [
                        ButtonSegment(
                          value: _MeetingFilter.all,
                          label: Text('All (${stats.total})'),
                          icon: const Icon(Icons.list_rounded, size: 18),
                        ),
                        ButtonSegment(
                          value: _MeetingFilter.today,
                          label: Text('Today (${stats.today})'),
                          icon: const Icon(Icons.today_rounded, size: 18),
                        ),
                        ButtonSegment(
                          value: _MeetingFilter.upcoming,
                          label: Text('Soon (${stats.upcoming})'),
                          icon: const Icon(Icons.upcoming_rounded, size: 18),
                        ),
                        ButtonSegment(
                          value: _MeetingFilter.priority,
                          label: Text('Priority (${stats.highPriority})'),
                          icon: const Icon(Icons.flag_rounded, size: 18),
                        ),
                      ],
                      selected: {_filter},
                      onSelectionChanged: (value) {
                        setState(() => _filter = value.first);
                      },
                      showSelectedIcon: false,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: _MeetingsBody(
                state: state,
                permissions: permissions,
                userId: userId,
                isBoss: isBoss,
                filter: _filter,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BossMeetingsHeader extends StatelessWidget {
  const _BossMeetingsHeader({
    required this.total,
    required this.upcoming,
  });

  final int total;
  final int upcoming;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: AppRadius.lgAll,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppColors.secondary.withValues(alpha: 0.28),
                  AppColors.primary.withValues(alpha: 0.18),
                ]
              : const [
                  Color(0xFFCCFBF1),
                  Color(0xFFDBEAFE),
                ],
        ),
        border: Border.all(
          color: isDark
              ? AppColors.secondary.withValues(alpha: 0.35)
              : AppColors.secondary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.18),
              borderRadius: AppRadius.mdAll,
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scheduled by your team',
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  total == 0
                      ? 'No meetings yet — pull to refresh when your team adds one.'
                      : '$upcoming upcoming · $total total on your calendar',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 280.ms);
  }
}

class _MeetingStats {
  const _MeetingStats({
    required this.total,
    required this.today,
    required this.upcoming,
    required this.highPriority,
    this.nextMeeting,
  });

  final int total;
  final int today;
  final int upcoming;
  final int highPriority;
  final Meeting? nextMeeting;

  factory _MeetingStats.from(List<Meeting> meetings) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final upcoming = meetings.where((m) => m.startAt.isAfter(now)).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    return _MeetingStats(
      total: meetings.length,
      today: meetings
          .where(
            (m) =>
                !m.startAt.isBefore(todayStart) && m.startAt.isBefore(todayEnd),
          )
          .length,
      upcoming: upcoming.length,
      highPriority: meetings
          .where(
            (m) =>
                m.priority == MeetingPriority.high ||
                m.priority == MeetingPriority.critical,
          )
          .length,
      nextMeeting: upcoming.isEmpty ? null : upcoming.first,
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final _MeetingStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatChip(
            label: 'Today',
            value: '${stats.today}',
            color: AppColors.primary,
            icon: Icons.today_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatChip(
            label: 'Upcoming',
            value: '${stats.upcoming}',
            color: AppColors.info,
            icon: Icons.event_available_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatChip(
            label: 'Priority',
            value: '${stats.highPriority}',
            color: AppColors.warning,
            icon: Icons.flag_rounded,
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: context.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: context.textTheme.labelSmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _NextMeetingBanner extends StatelessWidget {
  const _NextMeetingBanner({required this.meeting, required this.isBoss});

  final Meeting meeting;
  final bool isBoss;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final start = meeting.startAt.toLocal();
    final company = meeting.companyNameOrEmpty.trim();
    final mins = start.difference(DateTime.now()).inMinutes;
    final whenLabel = mins <= 0
        ? 'Now'
        : mins < 60
            ? 'In $mins min'
            : DateFormat('h:mm a').format(start);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.lgAll,
        onTap: () => context.push(RoutePaths.meetingDetailsPath(meeting.id)),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: AppRadius.lgAll,
            color: isDark
                ? scheme.primary.withValues(alpha: 0.16)
                : scheme.primaryContainer.withValues(alpha: 0.55),
            border: Border.all(
              color: scheme.primary.withValues(alpha: isDark ? 0.35 : 0.2),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: AppRadius.mdAll,
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: scheme.onPrimary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Next up',
                            style: context.textTheme.labelMedium?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.12),
                              borderRadius: AppRadius.fullAll,
                            ),
                            child: Text(
                              whenLabel,
                              style: context.textTheme.labelSmall?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        meeting.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        [
                          DateFormat('EEE, MMM d · h:mm a').format(start),
                          if (isBoss) meeting.organizerName,
                          if (company.isNotEmpty) company,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MeetingsBody extends ConsumerWidget {
  const _MeetingsBody({
    required this.state,
    required this.permissions,
    required this.userId,
    required this.isBoss,
    required this.filter,
  });

  final MeetingsState state;
  final PermissionSet permissions;
  final String? userId;
  final bool isBoss;
  final _MeetingFilter filter;

  List<Meeting> _filtered(List<Meeting> source) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    return switch (filter) {
      _MeetingFilter.all => source,
      _MeetingFilter.today => source
          .where(
            (m) =>
                !m.startAt.isBefore(todayStart) && m.startAt.isBefore(todayEnd),
          )
          .toList(),
      _MeetingFilter.upcoming =>
        source.where((m) => m.startAt.isAfter(now)).toList(),
      _MeetingFilter.priority => source
          .where(
            (m) =>
                m.priority == MeetingPriority.high ||
                m.priority == MeetingPriority.critical,
          )
          .toList(),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading && state.meetings.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: SkeletonLoader(itemCount: 5),
      );
    }

    if (state.status == MeetingsStatus.error && state.meetings.isEmpty) {
      return ErrorView(
        failure: UnknownFailure(state.errorMessage ?? 'Failed to load'),
        onRetry: () {
          ref.read(meetingsControllerProvider.notifier).load(null);
        },
      );
    }

    final meetings = _filtered(
      [...state.meetings]..sort((a, b) => a.startAt.compareTo(b.startAt)),
    );

    if (state.meetings.isEmpty) {
      return MeetingEmptyState(
        icon: Icons.event_note_rounded,
        title: 'No meetings yet',
        message: isBoss
            ? 'Your team will create meetings for you. Pull down to refresh.'
            : 'Create a meeting for the Boss. Keep title, time, and agenda clear.',
        actionLabel: isBoss ? null : 'New meeting',
        onAction: isBoss
            ? null
            : () => context.push(RoutePaths.meetingCreate),
      );
    }

    if (meetings.isEmpty) {
      return MeetingEmptyState(
        icon: Icons.filter_alt_outlined,
        title: 'Nothing in this filter',
        message: 'Try All, Today, Soon, or Priority to see your meetings.',
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(meetingsControllerProvider.notifier).load(null),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        itemCount: meetings.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final meeting = meetings[index];
          final canEdit =
              userId != null &&
              permissions.canEditMeeting(
                currentUserId: userId!,
                meeting: MeetingAccessContext(
                  createdByUserId: meeting.createdByUserId,
                ),
              );
          return MeetingListCard(
            meeting: meeting,
            showOrganizer: isBoss,
            canEdit: canEdit,
            onEdit: canEdit
                ? () => context.push(RoutePaths.meetingEditPath(meeting.id))
                : null,
          ).animate().fadeIn(delay: (40 * index).ms).slideY(begin: 0.04, end: 0);
        },
      ),
    );
  }
}
