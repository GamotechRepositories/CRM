import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/rbac/app_permission.dart';
import '../../../../core/rbac/widgets/permission_gate.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/layout/app_scaffold.dart';
import '../../../../shared/widgets/loading/skeleton_loader.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../organization/presentation/providers/organization_providers.dart';
import '../../../organization/presentation/widgets/company_switcher.dart';
import '../providers/ea_dashboard_providers.dart';
import 'ea_calendar_panel.dart';
import 'ea_dashboard_widgets.dart';
import 'glass_panel.dart';

/// Simple single-company EA dashboard.
class EaDashboardView extends ConsumerStatefulWidget {
  const EaDashboardView({super.key});

  @override
  ConsumerState<EaDashboardView> createState() => _EaDashboardViewState();
}

class _EaDashboardViewState extends ConsumerState<EaDashboardView> {
  late DateTime _focusMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusMonth = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(eaDashboardProvider);
    final company = ref.watch(activeCompanyProvider);
    final user = ref.watch(authSessionProvider).session?.user;
    final name = user?.displayName?.split(' ').first ?? 'there';
    final selected = state.selectedDay ?? DateTime.now();
    final dayMeetings = state.meetingsOn(selected);
    final needsAttention = [
      ...state.pendingInvitations.map(
        (i) => (
          id: i.id,
          title: i.title,
          subtitle:
              'Invite · ${i.fromName} · ${DateFormat('MMM d, h:mm a').format(i.scheduledAt.toLocal())}',
          type: 'invite',
        ),
      ),
      ...state.pendingRequests.map(
        (r) => (
          id: r.id,
          title: r.title,
          subtitle:
              'Request · ${r.requesterName} · ${DateFormat('MMM d, h:mm a').format(r.preferredAt.toLocal())}',
          type: 'request',
        ),
      ),
    ];
    final scheme = Theme.of(context).colorScheme;

    return AppScaffold(
      maxContentWidth: 800,
      padFloatingNav: true,
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          const CompanySwitcherButton(),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              await ref.read(authSessionProvider.notifier).logout();
              if (context.mounted) context.go(RoutePaths.login);
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      floatingActionButton: PermissionGate(
        permission: AppPermission.createMeeting,
        child: FloatingActionButton.extended(
          heroTag: 'ea_create_meeting_fab',
          onPressed: () => context.push(RoutePaths.meetingCreate),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Create Meeting'),
        ).animate().fadeIn().scale(begin: const Offset(0.92, 0.92)),
      ),
      body: state.isLoading && state.meetings.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: SkeletonLoader(itemCount: 5),
            )
          : RefreshIndicator(
              onRefresh: () =>
                  ref.read(eaDashboardProvider.notifier).load(company?.id),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  120,
                ),
                children: [
                  Text(
                    'Hello, $name',
                    style: context.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ).animate().fadeIn().slideY(begin: 0.08, end: 0),
                  const SizedBox(height: 4),
                  Text(
                    company == null ? 'Your company meetings' : company.name,
                    style: context.textTheme.titleMedium?.copyWith(
                      color: company?.color ?? scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          label: 'Today',
                          value: state.todaysMeetings.length,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _StatTile(
                          label: 'Needs action',
                          value: needsAttention.length,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Calendar',
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  EaCalendarPanel(
                    focusMonth: _focusMonth,
                    selectedDay: selected,
                    meetingDays: state.meetingDays,
                    onSelectDay: (day) =>
                        ref.read(eaDashboardProvider.notifier).selectDay(day),
                    onPrevMonth: () {
                      setState(() {
                        _focusMonth = DateTime(
                          _focusMonth.year,
                          _focusMonth.month - 1,
                        );
                      });
                    },
                    onNextMonth: () {
                      setState(() {
                        _focusMonth = DateTime(
                          _focusMonth.year,
                          _focusMonth.month + 1,
                        );
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    DateFormat('EEEE, MMM d').format(selected),
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (dayMeetings.isEmpty)
                    GlassPanel(
                      child: Text(
                        'No meetings on this day.',
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    ...dayMeetings.asMap().entries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: EaMeetingTile(
                          meeting: e.value,
                          index: e.key,
                          onTap: () => context.push(
                            RoutePaths.meetingEditPath(e.value.id),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Needs attention',
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (needsAttention.isEmpty)
                    GlassPanel(
                      child: Text(
                        'You are all caught up.',
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    ...needsAttention.map((item) {
                      final isInvite = item.type == 'invite';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: GlassPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: context.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.subtitle,
                                style: context.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Row(
                                children: [
                                  FilledButton(
                                    onPressed: () {
                                      if (isInvite) {
                                        ref
                                            .read(eaDashboardProvider.notifier)
                                            .acceptInvitation(item.id);
                                        context.showAppSnackBar('Accepted');
                                      } else {
                                        ref
                                            .read(eaDashboardProvider.notifier)
                                            .approveRequest(item.id);
                                        context.showAppSnackBar('Approved');
                                      }
                                    },
                                    child: Text(
                                      isInvite ? 'Accept' : 'Approve',
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  TextButton(
                                    onPressed: () {
                                      if (isInvite) {
                                        ref
                                            .read(eaDashboardProvider.notifier)
                                            .declineInvitation(item.id);
                                      } else {
                                        ref
                                            .read(eaDashboardProvider.notifier)
                                            .rejectRequest(item.id);
                                      }
                                      context.showAppSnackBar('Declined');
                                    },
                                    child: const Text('Decline'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
