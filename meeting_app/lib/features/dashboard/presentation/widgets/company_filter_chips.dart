import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../companies/domain/entities/company.dart';
import '../../../organization/domain/organization_constants.dart';

class CompanyFilterChips extends StatelessWidget {
  const CompanyFilterChips({
    super.key,
    required this.companies,
    required this.selectedCompanyId,
    required this.onSelected,
  });

  final List<Company> companies;
  final String? selectedCompanyId;
  final ValueChanged<String?> onSelected;

  String _chipLabel(Company company) {
    for (final spec in OrganizationConstants.demoCompanies) {
      if (spec.id == company.id) return spec.chipLabel;
    }
    return company.name;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: FilterChip(
              selected: selectedCompanyId == null,
              label: const Text('All Companies'),
              avatar: selectedCompanyId == null
                  ? const Icon(Icons.apartment_rounded, size: 16)
                  : null,
              onSelected: (_) => onSelected(null),
              showCheckmark: false,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
            ),
          ),
          ...companies.asMap().entries.map((entry) {
            final index = entry.key;
            final company = entry.value;
            final selected = selectedCompanyId == company.id;
            return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: Hero(
                    tag: 'boss_company_chip_${company.id}',
                    child: Material(
                      color: Colors.transparent,
                      child: FilterChip(
                        selected: selected,
                        label: Text(_chipLabel(company)),
                        avatar: CircleAvatar(
                          backgroundColor: company.color.withValues(alpha: 0.2),
                          radius: 10,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: company.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        onSelected: (_) => onSelected(company.id),
                        showCheckmark: false,
                        selectedColor: company.color.withValues(alpha: 0.18),
                        side: BorderSide(
                          color: selected
                              ? company.color
                              : Theme.of(
                                  context,
                                ).colorScheme.outline.withValues(alpha: 0.35),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.mdAll,
                        ),
                      ),
                    ),
                  ),
                )
                .animate(delay: (40 * index).ms)
                .fadeIn(duration: 350.ms)
                .slideX(begin: 0.08, end: 0);
          }),
        ],
      ),
    );
  }
}
