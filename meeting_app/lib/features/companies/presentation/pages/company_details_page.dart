import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/layout/app_scaffold.dart';
import '../../../../shared/widgets/loading/loading_overlay.dart';
import '../../../../shared/widgets/loading/skeleton_loader.dart';
import '../../../employees/presentation/providers/employee_providers.dart';
import '../../domain/entities/company.dart';
import '../providers/company_providers.dart';
import '../states/company_detail_state.dart';
import '../widgets/company_card.dart';
import '../widgets/company_form_widgets.dart';

class CompanyDetailsPage extends ConsumerWidget {
  const CompanyDetailsPage({super.key, required this.companyId});

  final String companyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(companyDetailControllerProvider(companyId));

    return AppScaffold(
      maxContentWidth: 800,
      appBar: AppBar(
        title: Text(state.company?.name ?? 'Company'),
        actions: [
          if (state.company != null) ...[
            IconButton(
              tooltip: 'Edit',
              onPressed: () =>
                  context.push(RoutePaths.companyEditPath(companyId)),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Delete',
              onPressed: () => _delete(context, ref, state.company!),
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
    CompanyDetailState state,
  ) {
    if (state.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: SkeletonLoader(itemCount: 4),
      );
    }

    if (state.status == CompanyDetailStatus.error || state.company == null) {
      return ErrorView(
        failure: UnknownFailure(state.errorMessage ?? 'Company not found'),
        onRetry: () => ref
            .read(companyDetailControllerProvider(companyId).notifier)
            .load(),
      );
    }

    final company = state.company!;
    final dateFormat = DateFormat.yMMMd();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _HeroHeader(
          company: company,
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.06, end: 0),
        const SizedBox(height: AppSpacing.lg),
        _InfoSection(
          title: 'Overview',
          children: [
            _InfoRow(
              icon: Icons.category_outlined,
              label: 'Industry',
              value: company.industry,
            ),
            _InfoRow(
              icon: Icons.people_outline,
              label: 'Employees',
              value: '${company.employeeCount}',
            ),
            _InfoRow(
              icon: Icons.flag_outlined,
              label: 'Status',
              value: company.isActive ? 'Active' : 'Inactive',
              trailing: CompanyStatusChip(status: company.status),
            ),
          ],
        ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.05, end: 0),
        const SizedBox(height: AppSpacing.md),
        _EmployeesEntryCard(
          companyId: companyId,
        ).animate().fadeIn(delay: 110.ms).slideY(begin: 0.05, end: 0),
        const SizedBox(height: AppSpacing.md),
        _InfoSection(
          title: 'Contact',
          children: [
            _InfoRow(
              icon: Icons.location_on_outlined,
              label: 'Address',
              value: company.address,
            ),
            if (company.website.isNotEmpty)
              _InfoRow(
                icon: Icons.language_rounded,
                label: 'Website',
                value: company.website,
              ),
            if (company.email.isNotEmpty)
              _InfoRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: company.email,
              ),
            if (company.phone.isNotEmpty)
              _InfoRow(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: company.phone,
              ),
          ],
        ).animate().fadeIn(delay: 140.ms).slideY(begin: 0.05, end: 0),
        const SizedBox(height: AppSpacing.md),
        _InfoSection(
          title: 'Meta',
          children: [
            _InfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Created',
              value: dateFormat.format(company.createdAt),
            ),
            _InfoRow(
              icon: Icons.update_outlined,
              label: 'Updated',
              value: dateFormat.format(company.updatedAt),
            ),
          ],
        ).animate().fadeIn(delay: 200.ms),
      ],
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Company company,
  ) async {
    final confirmed = await showCompanyDeleteDialog(
      context,
      companyName: company.name,
    );
    if (!confirmed) return;

    final ok = await ref
        .read(companyDetailControllerProvider(companyId).notifier)
        .delete();
    if (!context.mounted) return;

    if (ok) {
      ref.invalidate(companiesControllerProvider);
      context.showAppSnackBar('${company.name} deleted');
      context.go(RoutePaths.companies);
    } else {
      final err = ref
          .read(companyDetailControllerProvider(companyId))
          .errorMessage;
      context.showAppSnackBar(err ?? 'Delete failed', isError: true);
    }
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.company});

  final Company company;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            company.color.withValues(alpha: 0.22),
            company.color.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: company.color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          CompanyAvatar(
            company: company,
            size: 76,
            heroTag: 'company_logo_${company.id}',
          ).animate().scale(
            begin: const Offset(0.85, 0.85),
            curve: Curves.easeOutBack,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  company.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  company.industry,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                CompanyStatusChip(status: company.status),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.title, required this.children});

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

class _InfoRow extends StatelessWidget {
  const _InfoRow({
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

class _EmployeesEntryCard extends ConsumerWidget {
  const _EmployeesEntryCard({required this.companyId});

  final String companyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(employeesControllerProvider(companyId));
    final count = state.employees.length;
    final active = state.activeCount;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Team',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      context.push(RoutePaths.employeesPath(companyId)),
                  child: const Text('View all'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (state.isLoading)
              const LinearProgressIndicator()
            else ...[
              Text(
                count == 0
                    ? 'No employees yet for this company.'
                    : '$count team member${count == 1 ? '' : 's'} · $active active',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: count == 0 ? 'Add Employee' : 'Manage Employees',
                icon: count == 0
                    ? Icons.person_add_alt_1_rounded
                    : Icons.groups_outlined,
                isExpanded: true,
                onPressed: () => context.push(
                  count == 0
                      ? RoutePaths.employeeCreatePath(companyId)
                      : RoutePaths.employeesPath(companyId),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
