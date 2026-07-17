import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/employee.dart';

class EmployeeAvatar extends StatelessWidget {
  const EmployeeAvatar({
    super.key,
    required this.employee,
    this.size = 52,
    this.heroTag,
    this.showInitial = true,
  });

  final Employee employee;
  final double size;
  final String? heroTag;
  final bool showInitial;

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            employee.avatarColor,
            employee.avatarColor.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: employee.avatarColor.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: showInitial
            ? Text(
                employee.initial,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: size * 0.38,
                ),
              )
            : Icon(
                EmployeeAvatarIcons.resolve(employee.avatarIcon),
                color: Colors.white,
                size: size * 0.45,
              ),
      ),
    );

    if (heroTag == null) return avatar;
    return Hero(
      tag: heroTag!,
      child: Material(color: Colors.transparent, child: avatar),
    );
  }
}

class EmployeeRoleChip extends StatelessWidget {
  const EmployeeRoleChip({super.key, required this.role});

  final EmployeeRole role;

  @override
  Widget build(BuildContext context) {
    final color = switch (role) {
      EmployeeRole.boss => const Color(0xFF7C3AED),
      EmployeeRole.executiveAssistant => const Color(0xFF0369A1),
      EmployeeRole.manager => const Color(0xFF0F766E),
      EmployeeRole.teamLead => const Color(0xFFC2410C),
      EmployeeRole.employee => const Color(0xFF475569),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        role.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class EmployeeStatusChip extends StatelessWidget {
  const EmployeeStatusChip({super.key, required this.status});

  final EmployeeStatus status;

  @override
  Widget build(BuildContext context) {
    final active = status == EmployeeStatus.active;
    final fg = active
        ? const Color(0xFF059669)
        : Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
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

class EmployeeCard extends StatelessWidget {
  const EmployeeCard({
    super.key,
    required this.employee,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.index = 0,
  });

  final Employee employee;
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
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  EmployeeAvatar(
                    employee: employee,
                    heroTag: 'employee_avatar_${employee.id}',
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
                                employee.name,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            EmployeeStatusChip(status: employee.status),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${employee.designation} · ${employee.department}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            EmployeeRoleChip(role: employee.role),
                            if (employee.mobile.isNotEmpty)
                              Text(
                                '+91 ${employee.mobile}',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (onEdit != null || onDelete != null)
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'edit') onEdit?.call();
                        if (v == 'delete') onDelete?.call();
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
        .fadeIn(delay: (50 * index).ms, duration: 320.ms)
        .slideY(begin: 0.07, end: 0)
        .scale(begin: const Offset(0.98, 0.98), end: const Offset(1, 1));
  }
}

class EmployeeFilterBar extends StatelessWidget {
  const EmployeeFilterBar({
    super.key,
    required this.department,
    required this.role,
    required this.status,
    required this.onDepartment,
    required this.onRole,
    required this.onStatus,
    required this.onClear,
    required this.hasFilters,
  });

  final String? department;
  final EmployeeRole? role;
  final EmployeeStatus? status;
  final ValueChanged<String?> onDepartment;
  final ValueChanged<EmployeeRole?> onRole;
  final ValueChanged<EmployeeStatus?> onStatus;
  final VoidCallback onClear;
  final bool hasFilters;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          FilterChip(
            label: Text(department ?? 'Department'),
            selected: department != null,
            onSelected: (_) async {
              final value = await showModalBottomSheet<String>(
                context: context,
                showDragHandle: true,
                builder: (context) => _FilterSheet(
                  title: 'Filter by department',
                  options: ['All', ...EmployeeDepartments.all],
                  selected: department ?? 'All',
                ),
              );
              if (value == null) return;
              onDepartment(value == 'All' ? null : value);
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text(role?.label ?? 'Role'),
            selected: role != null,
            onSelected: (_) async {
              final labels = [
                'All',
                ...EmployeeRole.values.map((e) => e.label),
              ];
              final value = await showModalBottomSheet<String>(
                context: context,
                showDragHandle: true,
                builder: (context) => _FilterSheet(
                  title: 'Filter by role',
                  options: labels,
                  selected: role?.label ?? 'All',
                ),
              );
              if (value == null) return;
              if (value == 'All') {
                onRole(null);
              } else {
                onRole(EmployeeRole.values.firstWhere((e) => e.label == value));
              }
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text(
              status == null
                  ? 'Status'
                  : (status == EmployeeStatus.active ? 'Active' : 'Inactive'),
            ),
            selected: status != null,
            onSelected: (_) async {
              final value = await showModalBottomSheet<String>(
                context: context,
                showDragHandle: true,
                builder: (context) => const _FilterSheet(
                  title: 'Filter by status',
                  options: ['All', 'Active', 'Inactive'],
                  selected: 'All',
                ),
              );
              if (value == null) return;
              onStatus(switch (value) {
                'Active' => EmployeeStatus.active,
                'Inactive' => EmployeeStatus.inactive,
                _ => null,
              });
            },
          ),
          if (hasFilters) ...[
            const SizedBox(width: 8),
            ActionChip(
              avatar: const Icon(Icons.clear, size: 16),
              label: const Text('Clear'),
              onPressed: onClear,
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterSheet extends StatelessWidget {
  const _FilterSheet({
    required this.title,
    required this.options,
    required this.selected,
  });

  final String title;
  final List<String> options;
  final String selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: options
                  .map(
                    (o) => ListTile(
                      title: Text(o),
                      trailing: o == selected
                          ? Icon(
                              Icons.check,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                      onTap: () => Navigator.pop(context, o),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool> showEmployeeDeleteDialog(
  BuildContext context, {
  required String employeeName,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete employee?'),
      content: Text('“$employeeName” will be removed from this company.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return result ?? false;
}

class EmployeeAvatarPicker extends StatelessWidget {
  const EmployeeAvatarPicker({
    super.key,
    required this.selectedIcon,
    required this.selectedColor,
    required this.onIconSelected,
    required this.onColorSelected,
  });

  final String selectedIcon;
  final int selectedColor;
  final ValueChanged<String> onIconSelected;
  final ValueChanged<int> onColorSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Profile style', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: EmployeeAvatarIcons.icons.entries.map((e) {
            final selected = e.key == selectedIcon;
            return ChoiceChip(
              selected: selected,
              label: Icon(e.value, size: 18),
              onSelected: (_) => onIconSelected(e.key),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Avatar color', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: EmployeeAvatarColors.presets.map((color) {
            final selected = color.toARGB32() == selectedColor;
            return GestureDetector(
              onTap: () => onColorSelected(color.toARGB32()),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? Theme.of(context).colorScheme.onSurface
                        : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
