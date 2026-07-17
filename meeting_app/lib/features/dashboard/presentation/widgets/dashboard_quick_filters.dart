import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../states/boss_dashboard_state.dart';

class DashboardQuickFilters extends StatelessWidget {
  const DashboardQuickFilters({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final BossQuickFilter selected;
  final ValueChanged<BossQuickFilter> onSelected;

  static const _items = <(BossQuickFilter, String, IconData)>[
    (BossQuickFilter.all, 'All', Icons.grid_view_rounded),
    (BossQuickFilter.today, 'Today', Icons.today_rounded),
    (BossQuickFilter.upcoming, 'Upcoming', Icons.upcoming_rounded),
    (
      BossQuickFilter.highPriority,
      'High Priority',
      Icons.priority_high_rounded,
    ),
    (BossQuickFilter.team, 'Team', Icons.groups_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: _items.map((item) {
        final (filter, label, icon) = item;
        final isSelected = selected == filter;
        return ChoiceChip(
          selected: isSelected,
          label: Text(label),
          avatar: Icon(icon, size: 16),
          onSelected: (_) => onSelected(filter),
          showCheckmark: false,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        );
      }).toList(),
    ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.06, end: 0);
  }
}
