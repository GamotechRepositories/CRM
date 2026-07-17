import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/layout/app_scaffold.dart';
import '../../../../shared/widgets/loading/skeleton_loader.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../organization/presentation/providers/organization_providers.dart';
import '../../../organization/presentation/widgets/company_switcher.dart';
import '../providers/boss_dashboard_providers.dart';
import '../states/boss_dashboard_state.dart';
import 'company_filter_chips.dart';
import 'glass_panel.dart';
import 'meeting_section_widgets.dart';

/// Simple portfolio overview for Boss — view only.
class BossDashboardView extends ConsumerStatefulWidget {
  const BossDashboardView({super.key});

  @override
  ConsumerState<BossDashboardView> createState() => _BossDashboardViewState();
}

class _BossDashboardViewState extends ConsumerState<BossDashboardView> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bossDashboardProvider);
    final companies = ref.watch(companyContextProvider).companies;
    final user = ref.watch(authSessionProvider).session?.user;
    final name = user?.displayName?.split(' ').first ?? 'there';
    final meetings = state.scopedMeetings;
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
      body: state.isLoading && state.allMeetings.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: SkeletonLoader(itemCount: 5),
            )
          : RefreshIndicator(
              onRefresh: () =>
                  ref.read(bossDashboardProvider.notifier).load(companies),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.xxl,
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
                    'Meetings across all your companies',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _SimpleStats(
                    today: state.todaysMeetings.length,
                    upcoming: state.upcomingMeetings.length,
                    high: state.highPriorityMeetings.length,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Company',
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  CompanyFilterChips(
                    companies: companies,
                    selectedCompanyId: state.selectedCompanyId,
                    onSelected: (id) => ref
                        .read(bossDashboardProvider.notifier)
                        .selectCompany(id),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SegmentedButton<BossQuickFilter>(
                    segments: const [
                      ButtonSegment(
                        value: BossQuickFilter.all,
                        label: Text('All'),
                      ),
                      ButtonSegment(
                        value: BossQuickFilter.today,
                        label: Text('Today'),
                      ),
                      ButtonSegment(
                        value: BossQuickFilter.upcoming,
                        label: Text('Upcoming'),
                      ),
                      ButtonSegment(
                        value: BossQuickFilter.highPriority,
                        label: Text('Priority'),
                      ),
                    ],
                    selected: {state.quickFilter},
                    onSelectionChanged: (s) => ref
                        .read(bossDashboardProvider.notifier)
                        .setQuickFilter(s.first),
                    showSelectedIcon: false,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _searchController,
                    onChanged: (q) =>
                        ref.read(bossDashboardProvider.notifier).setSearch(q),
                    decoration: InputDecoration(
                      hintText: 'Search meetings',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Text(
                        'Meetings',
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${meetings.length}',
                        style: context.textTheme.labelLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (state.status == BossDashboardStatus.error)
                    GlassPanel(
                      child: Text(
                        state.errorMessage ?? 'Could not load meetings',
                        style: TextStyle(color: scheme.error),
                      ),
                    )
                  else if (meetings.isEmpty)
                    GlassPanel(
                      child: Text(
                        'No meetings match these filters.',
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    ...meetings.asMap().entries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: PortfolioMeetingTile(
                          item: e.value,
                          index: e.key,
                          compact: true,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _SimpleStats extends StatelessWidget {
  const _SimpleStats({
    required this.today,
    required this.upcoming,
    required this.high,
  });

  final int today;
  final int upcoming;
  final int high;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Today',
            value: today,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatCard(
            label: 'Upcoming',
            value: upcoming,
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatCard(
            label: 'Priority',
            value: high,
            color: AppColors.error,
          ),
        ),
      ],
    ).animate().fadeIn(delay: 60.ms);
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
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
