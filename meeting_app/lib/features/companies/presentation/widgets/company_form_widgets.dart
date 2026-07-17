import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/feedback/error_view.dart';

class CompaniesEmptyState extends StatelessWidget {
  const CompaniesEmptyState({
    super.key,
    required this.onAdd,
    this.canAdd = true,
  });

  final VoidCallback onAdd;
  final bool canAdd;

  @override
  Widget build(BuildContext context) {
    return EmptyView(
      title: canAdd ? 'No companies yet' : 'No company assigned',
      message: canAdd
          ? 'Create your first company to start organizing meetings and teams.'
          : 'Ask your Boss to assign you to a company.',
      icon: Icons.domain_disabled_outlined,
      actionLabel: canAdd ? 'Add Company' : null,
      onAction: canAdd ? onAdd : null,
    ).animate().fadeIn().scale(begin: const Offset(0.96, 0.96));
  }
}

class CompanySearchField extends StatelessWidget {
  const CompanySearchField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search companies…',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear',
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
                icon: const Icon(Icons.close_rounded),
              ),
      ),
    );
  }
}

Future<bool> showCompanyDeleteDialog(
  BuildContext context, {
  required String companyName,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete company?'),
      content: Text(
        '“$companyName” will be permanently removed. This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return result ?? false;
}

class CompanyColorPicker extends StatelessWidget {
  const CompanyColorPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: CompanyColorsPresets.colors.map((color) {
        final selectedColor = color.toARGB32() == selected;
        return GestureDetector(
          onTap: () => onSelected(color.toARGB32()),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selectedColor
                    ? Theme.of(context).colorScheme.onSurface
                    : Colors.transparent,
                width: 2.5,
              ),
              boxShadow: [
                if (selectedColor)
                  BoxShadow(
                    color: color.withValues(alpha: 0.45),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
              ],
            ),
            child: selectedColor
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : null,
          ),
        );
      }).toList(),
    );
  }
}

/// Local alias to avoid importing entity colors with Flutter Color conflict in widgets.
abstract final class CompanyColorsPresets {
  static const List<Color> colors = [
    Color(0xFF1D4ED8),
    Color(0xFF0F766E),
    Color(0xFF7C3AED),
    Color(0xFFBE123C),
    Color(0xFFC2410C),
    Color(0xFF047857),
    Color(0xFF0369A1),
    Color(0xFF4F46E5),
  ];
}

class CompanyLogoPicker extends StatelessWidget {
  const CompanyLogoPicker({
    super.key,
    required this.selected,
    required this.color,
    required this.onSelected,
  });

  final String selected;
  final Color color;
  final ValueChanged<String> onSelected;

  static const _keys = [
    'business',
    'apartment',
    'store',
    'factory',
    'school',
    'health',
    'finance',
    'tech',
  ];

  static const _icons = {
    'business': Icons.business_rounded,
    'apartment': Icons.apartment_rounded,
    'store': Icons.storefront_rounded,
    'factory': Icons.factory_rounded,
    'school': Icons.school_rounded,
    'health': Icons.local_hospital_rounded,
    'finance': Icons.account_balance_rounded,
    'tech': Icons.memory_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: _keys.map((key) {
        final isSelected = key == selected;
        return ChoiceChip(
          selected: isSelected,
          label: Icon(_icons[key], size: 20, color: isSelected ? color : null),
          onSelected: (_) => onSelected(key),
        );
      }).toList(),
    );
  }
}
