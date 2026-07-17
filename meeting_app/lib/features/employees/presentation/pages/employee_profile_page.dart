import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/layout/app_scaffold.dart';
import '../../../../shared/widgets/loading/loading_overlay.dart';
import '../../../../shared/widgets/loading/skeleton_loader.dart';
import '../../domain/entities/employee.dart';
import '../providers/employee_providers.dart';
import '../states/employee_detail_state.dart';
import '../widgets/employee_widgets.dart';

class EmployeeProfilePage extends ConsumerWidget {
  const EmployeeProfilePage({
    super.key,
    required this.companyId,
    required this.employeeId,
  });

  final String companyId;
  final String employeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(employeeDetailControllerProvider(employeeId));

    return AppScaffold(
      maxContentWidth: 800,
      appBar: AppBar(
        title: Text(state.employee?.name ?? 'Profile'),
        actions: [
          if (state.employee != null) ...[
            IconButton(
              tooltip: 'Edit',
              onPressed: () => context.push(
                RoutePaths.employeeEditPath(companyId, employeeId),
              ),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Delete',
              onPressed: () => _delete(context, ref, state.employee!),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ],
      ),
      body: LoadingOverlay(
        isLoading: state.isDeleting,
        message: 'Deleting…',
        child: _buildBody(context, ref, state),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    EmployeeDetailState state,
  ) {
    if (state.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: SkeletonLoader(itemCount: 5),
      );
    }

    if (state.status == EmployeeDetailStatus.error || state.employee == null) {
      return ErrorView(
        failure: UnknownFailure(state.errorMessage ?? 'Employee not found'),
        onRetry: () => ref
            .read(employeeDetailControllerProvider(employeeId).notifier)
            .load(),
      );
    }

    final employee = state.employee!;
    final dateFormat = DateFormat.yMMMd();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _ProfileHero(
          employee: employee,
          companyName: state.companyName,
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.06, end: 0),
        const SizedBox(height: AppSpacing.lg),
        _Section(
          title: 'Contact',
          children: [
            _Row(
              icon: Icons.phone_outlined,
              label: 'Mobile',
              value: '+91 ${employee.mobile}',
            ),
            _Row(
              icon: Icons.email_outlined,
              label: 'Email',
              value: employee.email,
            ),
          ],
        ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.05, end: 0),
        const SizedBox(height: AppSpacing.md),
        _Section(
          title: 'Organization',
          children: [
            _Row(
              icon: Icons.domain_outlined,
              label: 'Company',
              value: state.companyName ?? '—',
            ),
            _Row(
              icon: Icons.apartment_outlined,
              label: 'Department',
              value: employee.department,
            ),
            _Row(
              icon: Icons.work_outline,
              label: 'Designation',
              value: employee.designation,
            ),
            _Row(
              icon: Icons.shield_outlined,
              label: 'Role',
              value: employee.role.label,
              trailing: EmployeeRoleChip(role: employee.role),
            ),
            _Row(
              icon: Icons.flag_outlined,
              label: 'Status',
              value: employee.isActive ? 'Active' : 'Inactive',
              trailing: EmployeeStatusChip(status: employee.status),
            ),
          ],
        ).animate().fadeIn(delay: 140.ms).slideY(begin: 0.05, end: 0),
        const SizedBox(height: AppSpacing.md),
        _Section(
          title: 'Reporting',
          children: [
            if (state.manager != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: EmployeeAvatar(
                  employee: state.manager!,
                  size: 44,
                  heroTag: 'mgr_${state.manager!.id}',
                ),
                title: Text(state.manager!.name),
                subtitle: Text(
                  '${state.manager!.role.label} · Reporting Manager',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(
                  RoutePaths.employeeDetailsPath(companyId, state.manager!.id),
                ),
              )
            else
              const _Row(
                icon: Icons.supervisor_account_outlined,
                label: 'Manager',
                value: 'None assigned',
              ),
            if (state.directReports.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Direct reports (${state.directReports.length})',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              ...state.directReports.map(
                (e) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: EmployeeAvatar(employee: e, size: 40),
                  title: Text(e.name),
                  subtitle: Text(e.designation),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(
                    RoutePaths.employeeDetailsPath(companyId, e.id),
                  ),
                ),
              ),
            ],
          ],
        ).animate().fadeIn(delay: 200.ms),
        const SizedBox(height: AppSpacing.md),
        _Section(
          title: 'Meta',
          children: [
            _Row(
              icon: Icons.calendar_today_outlined,
              label: 'Joined',
              value: dateFormat.format(employee.createdAt),
            ),
            _Row(
              icon: Icons.update_outlined,
              label: 'Updated',
              value: dateFormat.format(employee.updatedAt),
            ),
          ],
        ).animate().fadeIn(delay: 240.ms),
      ],
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Employee employee,
  ) async {
    final confirmed = await showEmployeeDeleteDialog(
      context,
      employeeName: employee.name,
    );
    if (!confirmed) return;

    final ok = await ref
        .read(employeeDetailControllerProvider(employeeId).notifier)
        .delete();
    if (!context.mounted) return;

    if (ok) {
      ref.invalidate(employeesControllerProvider(companyId));
      context.showAppSnackBar('${employee.name} deleted');
      context.go(RoutePaths.employeesPath(companyId));
    } else {
      final err = ref
          .read(employeeDetailControllerProvider(employeeId))
          .errorMessage;
      context.showAppSnackBar(err ?? 'Delete failed', isError: true);
    }
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.employee, this.companyName});

  final Employee employee;
  final String? companyName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            employee.avatarColor.withValues(alpha: 0.28),
            employee.avatarColor.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: employee.avatarColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          EmployeeAvatar(
            employee: employee,
            size: 96,
            heroTag: 'employee_avatar_${employee.id}',
          ).animate().scale(
            begin: const Offset(0.85, 0.85),
            curve: Curves.easeOutBack,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            employee.name,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            employee.designation,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (companyName != null) ...[
            const SizedBox(height: 4),
            Text(companyName!, style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              EmployeeRoleChip(role: employee.role),
              EmployeeStatusChip(status: employee.status),
              Chip(
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.apartment, size: 16),
                label: Text(employee.department),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 2),
                Text(value, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
