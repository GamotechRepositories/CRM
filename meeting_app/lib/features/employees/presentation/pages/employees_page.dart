import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/rbac/app_permission.dart';
import '../../../../core/rbac/widgets/permission_gate.dart';
import '../../../../core/router/route_names.dart';
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
    final companyName = companyAsync.company?.name ?? 'Employees';

    return AppScaffold(
      maxContentWidth: 960,
      appBar: AppBar(
        title: Text(companyName),
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
