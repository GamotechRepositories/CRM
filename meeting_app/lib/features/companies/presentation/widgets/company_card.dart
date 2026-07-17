import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_radius.dart';
import '../../domain/entities/company.dart';

class CompanyAvatar extends StatelessWidget {
  const CompanyAvatar({
    super.key,
    required this.company,
    this.size = 52,
    this.heroTag,
  });

  final Company company;
  final double size;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: company.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(
          color: company.color.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Icon(
        CompanyLogoIcons.resolve(company.logoIcon),
        color: company.color,
        size: size * 0.48,
      ),
    );

    if (heroTag == null) return avatar;
    return Hero(
      tag: heroTag!,
      child: Material(color: Colors.transparent, child: avatar),
    );
  }
}

class CompanyStatusChip extends StatelessWidget {
  const CompanyStatusChip({super.key, required this.status});

  final CompanyStatus status;

  @override
  Widget build(BuildContext context) {
    final active = status == CompanyStatus.active;
    final scheme = Theme.of(context).colorScheme;
    final bg = active
        ? const Color(0xFF059669).withValues(alpha: 0.12)
        : scheme.error.withValues(alpha: 0.12);
    final fg = active ? const Color(0xFF059669) : scheme.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.full == 999
            ? BorderRadius.circular(999)
            : AppRadius.smAll,
      ),
      child: Text(
        active ? 'Active' : 'Inactive',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class CompanyCard extends StatelessWidget {
  const CompanyCard({
    super.key,
    required this.company,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.index = 0,
  });

  final Company company;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CompanyAvatar(
                    company: company,
                    heroTag: 'company_logo_${company.id}',
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                company.name,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            CompanyStatusChip(status: company.status),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          company.industry,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 14,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${company.employeeCount} employees',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            if (company.phone.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              Icon(
                                Icons.phone_outlined,
                                size: 14,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  company.phone,
                                  style: Theme.of(context).textTheme.labelSmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (onEdit != null || onDelete != null)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') onEdit?.call();
                        if (value == 'delete') onDelete?.call();
                      },
                      itemBuilder: (_) => [
                        if (onEdit != null)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                        if (onDelete != null)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(delay: (60 * index).ms, duration: 350.ms)
        .slideY(begin: 0.08, end: 0, delay: (60 * index).ms)
        .scale(
          begin: const Offset(0.98, 0.98),
          end: const Offset(1, 1),
          delay: (60 * index).ms,
        );
  }
}
