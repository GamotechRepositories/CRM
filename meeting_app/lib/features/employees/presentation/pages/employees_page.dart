import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/rbac/app_permission.dart';
import '../../../../core/rbac/widgets/permission_gate.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/layout/app_scaffold.dart';
import '../../../../shared/widgets/loading/loading_overlay.dart';
import '../../../../shared/widgets/loading/skeleton_loader.dart';
import '../../../companies/presentation/providers/company_providers.dart';
import '../../domain/entities/employee.dart';
import '../providers/employee_providers.dart';
import '../states/employees_state.dart';
import '../widgets/employee_widgets.dart';

class EmployeesPage extends ConsumerStatefulWidget {
  const EmployeesPage({super.key, required this.companyId});

  final String companyId;

  @override
  ConsumerState<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends ConsumerState<EmployeesPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _delete(Employee employee) async {
    final okConfirm = await showEmployeeDeleteDialog(
      context,
      employeeName: employee.name,
    );
    if (!okConfirm || !mounted) return;

    final ok = await ref
        .read(employeesControllerProvider(widget.companyId).notifier)
        .deleteEmployee(employee.id);
    if (!mounted) return;
    context.showAppSnackBar(
      ok ? '${employee.name} deleted' : 'Failed to delete',
      isError: !ok,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(employeesControllerProvider(widget.companyId));
    final companyAsync = ref.watch(
      companyDetailControllerProvider(widget.companyId),
    );
    final companyName = companyAsync.company?.name ?? 'Team';
    final industry = companyAsync.company?.industry.trim() ?? '';

    return AppScaffold(
      maxContentWidth: 960,
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Employees',
          style: context.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref
                .read(employeesControllerProvider(widget.companyId).notifier)
                .load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: PermissionGate(
        permission: AppPermission.manageEmployees,
        child: FloatingActionButton.extended(
          onPressed: () =>
              context.push(RoutePaths.employeeCreatePath(widget.companyId)),
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Add Employee'),
        ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),
      ),
      body: LoadingOverlay(
        isLoading: state.isDeleting,
        message: 'Deleting…',
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              child: _EmployeesHeroHeader(
                companyName: companyName,
                industry: industry,
                total: state.employees.length,
                active: state.activeCount,
                departments: state.countByDepartment.length,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (q) => ref
                    .read(
                      employeesControllerProvider(widget.companyId).notifier,
                    )
                    .setSearch(q),
                decoration: InputDecoration(
                  hintText: 'Search employees…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            ref
                                .read(
                                  employeesControllerProvider(
                                    widget.companyId,
                                  ).notifier,
                                )
                                .setSearch('');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ).animate().fadeIn().slideY(begin: -0.04, end: 0),
            ),
            EmployeeFilterBar(
              department: state.departmentFilter,
              role: state.roleFilter,
              status: state.statusFilter,
              hasFilters:
                  state.hasActiveFilters || state.searchQuery.isNotEmpty,
              onDepartment: (v) => ref
                  .read(employeesControllerProvider(widget.companyId).notifier)
                  .setDepartmentFilter(v),
              onRole: (v) => ref
                  .read(employeesControllerProvider(widget.companyId).notifier)
                  .setRoleFilter(v),
              onStatus: (v) => ref
                  .read(employeesControllerProvider(widget.companyId).notifier)
                  .setStatusFilter(v),
              onClear: () {
                _searchController.clear();
                ref
                    .read(
                      employeesControllerProvider(widget.companyId).notifier,
                    )
                    .clearFilters();
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            if (!state.isLoading && state.employees.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${state.filtered.length} employee${state.filtered.length == 1 ? '' : 's'}'
                    ' · ${state.activeCount} active',
                    style: context.textTheme.labelMedium,
                  ),
                ),
              ),
            if (!state.isLoading && state.employees.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              _StatsStrip(state: state),
            ],
            const SizedBox(height: AppSpacing.sm),
            Expanded(child: _buildBody(state)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(EmployeesState state) {
    if (state.isLoading && state.employees.isEmpty) {
      return const SkeletonLoader(itemCount: 6);
    }

    if (state.status == EmployeesStatus.error && state.employees.isEmpty) {
      return ErrorView(
        failure: UnknownFailure(state.errorMessage ?? 'Failed to load'),
        onRetry: () => ref
            .read(employeesControllerProvider(widget.companyId).notifier)
            .load(),
      );
    }

    if (state.isEmpty) {
      return EmptyView(
        title: state.hasActiveFilters || state.searchQuery.isNotEmpty
            ? 'No matches'
            : 'No employees yet',
        message: state.hasActiveFilters || state.searchQuery.isNotEmpty
            ? 'Try adjusting search or filters.'
            : 'Add your first team member to this company.',
        icon: Icons.groups_outlined,
        actionLabel: state.hasActiveFilters || state.searchQuery.isNotEmpty
            ? 'Clear filters'
            : 'Add Employee',
        onAction: () {
          if (state.hasActiveFilters || state.searchQuery.isNotEmpty) {
            _searchController.clear();
            ref
                .read(employeesControllerProvider(widget.companyId).notifier)
                .clearFilters();
          } else {
            context.push(RoutePaths.employeeCreatePath(widget.companyId));
          }
        },
      ).animate().fadeIn().scale(begin: const Offset(0.96, 0.96));
    }

    return RefreshIndicator(
      onRefresh: () => ref
          .read(employeesControllerProvider(widget.companyId).notifier)
          .load(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          100,
        ),
        itemCount: state.filtered.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final employee = state.filtered[index];
          return EmployeeCard(
            employee: employee,
            index: index,
            onTap: () => context.push(
              RoutePaths.employeeDetailsPath(widget.companyId, employee.id),
            ),
            onEdit: () => context.push(
              RoutePaths.employeeEditPath(widget.companyId, employee.id),
            ),
            onDelete: () => _delete(employee),
          );
        },
      ),
    );
  }
}

class _EmployeesHeroHeader extends StatelessWidget {
  const _EmployeesHeroHeader({
    required this.companyName,
    required this.industry,
    required this.total,
    required this.active,
    required this.departments,
  });

  final String companyName;
  final String industry;
  final int total;
  final int active;
  final int departments;

  @override
  Widget build(BuildContext context) {
    final inactive = (total - active).clamp(0, total);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: AppRadius.xlAll,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1D4ED8),
            Color(0xFF1E40AF),
            Color(0xFF0F766E),
          ],
          stops: [0.0, 0.55, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: AppRadius.lgAll,
                ),
                child: const Icon(
                  Icons.groups_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TEAM DIRECTORY',
                      style: context.textTheme.labelMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      companyName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (industry.isNotEmpty)
                      Text(
                        industry,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            total == 0
                ? 'Add people to build this company roster.'
                : 'Manage roles, departments, and access for your team.',
            style: context.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _HeaderStat(
                  label: 'Total',
                  value: '$total',
                  icon: Icons.people_alt_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeaderStat(
                  label: 'Active',
                  value: '$active',
                  icon: Icons.verified_user_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeaderStat(
                  label: departments > 0 ? 'Depts' : 'Inactive',
                  value: departments > 0 ? '$departments' : '$inactive',
                  icon: departments > 0
                      ? Icons.apartment_rounded
                      : Icons.person_off_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.06, end: 0);
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(height: 6),
          Text(
            value,
            style: context.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: context.textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.state});

  final EmployeesState state;

  @override
  Widget build(BuildContext context) {
    final roles = state.countByRole.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final depts = state.countByDepartment.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        children: [
          ...roles
              .take(3)
              .map(
                (e) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text('${e.key.label}: ${e.value}'),
                  ),
                ),
              ),
          ...depts
              .take(3)
              .map(
                (e) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.apartment, size: 16),
                    label: Text('${e.key}: ${e.value}'),
                  ),
                ),
              ),
        ],
      ),
    ).animate().fadeIn(delay: 80.ms);
  }
}
