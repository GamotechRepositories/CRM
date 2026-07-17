import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import 'glass_panel.dart';

/// Compact month calendar with meeting-day indicators.
class EaCalendarPanel extends StatelessWidget {
  const EaCalendarPanel({
    super.key,
    required this.focusMonth,
    required this.selectedDay,
    required this.meetingDays,
    required this.onSelectDay,
    required this.onPrevMonth,
    required this.onNextMonth,
  });

  final DateTime focusMonth;
  final DateTime selectedDay;
  final Set<DateTime> meetingDays;
  final ValueChanged<DateTime> onSelectDay;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;

  static const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _hasMeeting(DateTime day) => meetingDays.any((d) => _sameDay(d, day));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final first = DateTime(focusMonth.year, focusMonth.month, 1);
    final daysInMonth = DateTime(focusMonth.year, focusMonth.month + 1, 0).day;
    // Monday-based: DateTime.weekday is 1=Mon .. 7=Sun
    final leading = first.weekday - 1;
    final totalCells = leading + daysInMonth;
    final rows = ((totalCells + 6) ~/ 7);

    final monthLabel = MaterialLocalizations.of(
      context,
    ).formatMonthYear(focusMonth);

    return GlassPanel(
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: onPrevMonth,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  monthLabel,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: onNextMonth,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: _weekdays
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var row = 0; row < rows; row++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: List.generate(7, (col) {
                  final index = row * 7 + col;
                  final dayNum = index - leading + 1;
                  if (dayNum < 1 || dayNum > daysInMonth) {
                    return const Expanded(child: SizedBox(height: 40));
                  }
                  final day = DateTime(
                    focusMonth.year,
                    focusMonth.month,
                    dayNum,
                  );
                  final selected = _sameDay(day, selectedDay);
                  final hasMeeting = _hasMeeting(day);
                  final isToday = _sameDay(day, DateTime.now());

                  return Expanded(
                    child: InkWell(
                      borderRadius: AppRadius.mdAll,
                      onTap: () => onSelectDay(day),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 40,
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: selected
                              ? scheme.primary
                              : isToday
                              ? scheme.primaryContainer.withValues(alpha: 0.45)
                              : Colors.transparent,
                          borderRadius: AppRadius.mdAll,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$dayNum',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: selected
                                        ? scheme.onPrimary
                                        : scheme.onSurface,
                                  ),
                            ),
                            if (hasMeeting)
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? scheme.onPrimary
                                      : scheme.secondary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(delay: 60.ms).slideY(begin: 0.05, end: 0);
  }
}
