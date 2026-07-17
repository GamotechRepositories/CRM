import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/rbac/app_permission.dart';
import '../../../../core/rbac/rbac_providers.dart';
import '../../../../core/rbac/system_role.dart';
import '../../../../core/rbac/widgets/permission_gate.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../companies/presentation/widgets/company_card.dart';
import '../providers/organization_providers.dart';
import '../states/company_context_state.dart';

/// App-bar control for company switching (permission-gated).
class CompanySwitcherButton extends ConsumerWidget {
  const CompanySwitcherButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(companyContextProvider);
    final canSwitch = ref.watch(canSwitchCompanyProvider);
    final company = ctx.activeCompany;
    if (company == null) return const SizedBox.shrink();

    if (!canSwitch) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Chip(
          avatar: CompanyAvatar(company: company, size: 22),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 100),
                child: Text(company.name, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.lock_outline, size: 14),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: TextButton.icon(
        onPressed: () => showCompanySwitcherSheet(context, ref),
        icon: CompanyAvatar(company: company, size: 28),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 110),
              child: Text(
                company.name,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.labelLarge,
              ),
            ),
            const Icon(Icons.expand_more_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}

Future<void> showCompanySwitcherSheet(BuildContext context, WidgetRef ref) {
  final ctx = ref.read(companyContextProvider);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Switch company',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Portfolio · ${ctx.companies.length} companies',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: ctx.companies.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final company = ctx.companies[index];
                    final selected = company.id == ctx.activeCompanyId;
                    return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: selected
                                  ? company.color
                                  : Theme.of(context).colorScheme.outline
                                        .withValues(alpha: 0.3),
                            ),
                          ),
                          selected: selected,
                          leading: CompanyAvatar(company: company),
                          title: Text(
                            company.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(company.industry),
                          trailing: selected
                              ? Icon(Icons.check_circle, color: company.color)
                              : null,
                          onTap: () async {
                            final ok = await ref
                                .read(companyContextProvider.notifier)
                                .switchCompany(company.id);
                            if (context.mounted) {
                              Navigator.pop(context);
                              if (ok) {
                                context.showAppSnackBar(
                                  'Switched to ${company.name}',
                                );
                              }
                            }
                          },
                        )
                        .animate()
                        .fadeIn(delay: (40 * index).ms)
                        .slideY(begin: 0.05, end: 0);
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              PermissionGate(
                permission: AppPermission.viewCompaniesNav,
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      context.go(RoutePaths.companies);
                    },
                    icon: const Icon(Icons.domain_outlined),
                    label: const Text('Manage all companies'),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Dashboard card summarizing the active company + portfolio.
class ActiveCompanyDashboardCard extends ConsumerWidget {
  const ActiveCompanyDashboardCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(companyContextProvider);
    final company = ctx.activeCompany;
    final canSwitch = ref.watch(canSwitchCompanyProvider);
    final canManage = ref.watch(canManageCompaniesProvider);
    final roleLabel = ref.watch(systemRoleProvider)?.label;

    if (ctx.status == CompanyContextStatus.loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: LinearProgressIndicator(),
        ),
      );
    }

    if (company == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('No company access', style: context.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(
                canManage
                    ? 'Create your first company to get started.'
                    : 'Your account is not linked to a company.',
                style: context.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(RoutePaths.companyDetailsPath(company.id)),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                company.color.withValues(alpha: 0.18),
                company.color.withValues(alpha: 0.04),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CompanyAvatar(
                    company: company,
                    size: 56,
                    heroTag: 'active_company_${company.id}',
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Active company',
                          style: context.textTheme.labelMedium,
                        ),
                        Text(
                          company.name,
                          style: context.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          company.industry,
                          style: context.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (canSwitch)
                    IconButton(
                      tooltip: 'Switch company',
                      onPressed: () => showCompanySwitcherSheet(context, ref),
                      icon: const Icon(Icons.swap_horiz_rounded),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PermissionGate(
                    permission: AppPermission.switchCompany,
                    child: Chip(
                      avatar: const Icon(Icons.apartment, size: 16),
                      label: Text('${ctx.companies.length} owned'),
                    ),
                  ),
                  if (roleLabel != null)
                    Chip(
                      avatar: const Icon(Icons.badge_outlined, size: 16),
                      label: Text(roleLabel),
                    ),
                  PermissionGate(
                    permission: AppPermission.viewEmployees,
                    child: ActionChip(
                      avatar: const Icon(Icons.groups_outlined, size: 16),
                      label: const Text('Employees'),
                      onPressed: () =>
                          context.push(RoutePaths.employeesPath(company.id)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.05, end: 0);
  }
}
