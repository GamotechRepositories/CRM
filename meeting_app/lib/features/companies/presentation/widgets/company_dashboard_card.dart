import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../domain/entities/company.dart';
import 'company_card.dart';

/// Compact companies summary card for the Dashboard.
class CompanyDashboardCard extends StatelessWidget {
  const CompanyDashboardCard({
    super.key,
    required this.companies,
    required this.isLoading,
    this.errorMessage,
  });

  final List<Company> companies;
  final bool isLoading;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final active = companies.where((c) => c.isActive).length;
    final preview = companies.take(3).toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'My Companies',
                  style: context.textTheme.titleLarge,
                ),
              ),
              TextButton(
                onPressed: () => context.go(RoutePaths.companies),
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (isLoading)
            const LinearProgressIndicator()
          else if (errorMessage != null)
            Text(
              errorMessage!,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.error,
              ),
            )
          else ...[
            Row(
              children: [
                _StatPill(
                  label: 'Total',
                  value: '${companies.length}',
                  color: context.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                _StatPill(
                  label: 'Active',
                  value: '$active',
                  color: const Color(0xFF059669),
                ),
              ],
            ).animate().fadeIn().slideX(begin: -0.05, end: 0),
            const SizedBox(height: AppSpacing.md),
            if (companies.isEmpty)
              Text(
                'No companies yet. Add your first company to get started.',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...preview.asMap().entries.map((entry) {
                final company = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child:
                      ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CompanyAvatar(
                              company: company,
                              size: 42,
                              heroTag: 'dash_company_${company.id}',
                            ),
                            title: Text(
                              company.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(company.industry),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => context.push(
                              RoutePaths.companyDetailsPath(company.id),
                            ),
                          )
                          .animate()
                          .fadeIn(delay: (80 * entry.key).ms)
                          .slideY(begin: 0.06, end: 0),
                );
              }),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: companies.isEmpty ? 'Add Company' : 'Manage Companies',
              icon: companies.isEmpty
                  ? Icons.add_business_rounded
                  : Icons.domain,
              isExpanded: true,
              onPressed: () => context.go(
                companies.isEmpty
                    ? RoutePaths.companyCreate
                    : RoutePaths.companies,
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.05, end: 0);
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
