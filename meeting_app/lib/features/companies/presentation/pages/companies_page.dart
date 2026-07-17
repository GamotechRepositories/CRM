import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/rbac/app_permission.dart';
import '../../../../core/rbac/rbac_providers.dart';
import '../../../../core/rbac/widgets/permission_gate.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/layout/app_scaffold.dart';
import '../../../../shared/widgets/loading/loading_overlay.dart';
import '../../../../shared/widgets/loading/skeleton_loader.dart';
import '../../../organization/presentation/widgets/company_switcher.dart';
import '../../domain/entities/company.dart';
import '../providers/company_providers.dart';
import '../states/companies_state.dart';
import '../widgets/company_card.dart';
import '../widgets/company_form_widgets.dart';

class CompaniesPage extends ConsumerStatefulWidget {
  const CompaniesPage({super.key});

  @override
  ConsumerState<CompaniesPage> createState() => _CompaniesPageState();
}

class _CompaniesPageState extends ConsumerState<CompaniesPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _delete(Company company) async {
    final confirmed = await showCompanyDeleteDialog(
      context,
      companyName: company.name,
    );
    if (!confirmed || !mounted) return;

    final ok = await ref
        .read(companiesControllerProvider.notifier)
        .deleteCompany(company.id);
    if (!mounted) return;
    context.showAppSnackBar(
      ok ? '${company.name} deleted' : 'Failed to delete company',
      isError: !ok,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(companiesControllerProvider);
    final canCreate = ref.watch(
      canPermissionProvider(AppPermission.createCompany),
    );
    final canEdit = ref.watch(canPermissionProvider(AppPermission.editCompany));
    final canDelete = ref.watch(
      canPermissionProvider(AppPermission.deleteCompany),
    );

    return AppScaffold(
      maxContentWidth: 960,
      padFloatingNav: false,
      appBar: AppBar(
        title: Text(canCreate ? 'My Companies' : 'My Company'),
        actions: [
          const CompanySwitcherButton(),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () =>
                ref.read(companiesControllerProvider.notifier).load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: PermissionGate(
        permission: AppPermission.createCompany,
        child: FloatingActionButton.extended(
          onPressed: () => context.push(RoutePaths.companyCreate),
          icon: const Icon(Icons.add_business_rounded),
          label: const Text('Add Company'),
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
              child: CompanySearchField(
                controller: _searchController,
                onChanged: (q) =>
                    ref.read(companiesControllerProvider.notifier).search(q),
              ).animate().fadeIn().slideY(begin: -0.05, end: 0),
            ),
            if (!state.isLoading && state.companies.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${state.filtered.length} compan${state.filtered.length == 1 ? 'y' : 'ies'}'
                    '${state.searchQuery.isNotEmpty ? ' found' : ''}'
                    ' · ${state.activeCount} active',
                    style: context.textTheme.labelMedium,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: _buildBody(
                state,
                canCreate: canCreate,
                canEdit: canEdit,
                canDelete: canDelete,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    CompaniesState state, {
    required bool canCreate,
    required bool canEdit,
    required bool canDelete,
  }) {
    if (state.isLoading && state.companies.isEmpty) {
      return const SkeletonLoader(itemCount: 6);
    }

    if (state.status == CompaniesStatus.error && state.companies.isEmpty) {
      return ErrorView(
        failure: UnknownFailure(state.errorMessage ?? 'Failed to load'),
        onRetry: () => ref.read(companiesControllerProvider.notifier).load(),
      );
    }

    if (state.isEmpty) {
      return CompaniesEmptyState(
        canAdd: canCreate,
        onAdd: canCreate ? () => context.push(RoutePaths.companyCreate) : () {},
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(companiesControllerProvider.notifier).load(),
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
          final company = state.filtered[index];
          return CompanyCard(
            company: company,
            index: index,
            onTap: () =>
                context.push(RoutePaths.companyDetailsPath(company.id)),
            onEdit: canEdit
                ? () => context.push(RoutePaths.companyEditPath(company.id))
                : null,
            onDelete: canDelete ? () => _delete(company) : null,
          );
        },
      ),
    );
  }
}
