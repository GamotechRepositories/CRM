import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import 'glass_panel.dart';

class BossGreetingHeader extends StatelessWidget {
  const BossGreetingHeader({
    super.key,
    required this.name,
    required this.companyCount,
    required this.meetingCount,
  });

  final String name;
  final int companyCount;
  final int meetingCount;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final date = DateFormat('EEEE, MMMM d').format(DateTime.now());

    return GlassPanel(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            date.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              letterSpacing: 1.2,
              color: scheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
                '$_greeting, $name',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              )
              .animate()
              .fadeIn(duration: 450.ms)
              .slideY(begin: 0.12, end: 0, curve: Curves.easeOutCubic),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Executive portfolio across $companyCount companies · $meetingCount meetings in view',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ).animate().fadeIn(delay: 100.ms),
        ],
      ),
    );
  }
}

class DashboardSearchField extends StatefulWidget {
  const DashboardSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  State<DashboardSearchField> createState() => _DashboardSearchFieldState();
}

class _DashboardSearchFieldState extends State<DashboardSearchField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onText);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    super.dispose();
  }

  void _onText() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GlassPanel(
      padding: EdgeInsets.zero,
      child: TextField(
        controller: widget.controller,
        onChanged: widget.onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search meetings, companies, locations…',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: widget.controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear',
                  onPressed: () {
                    widget.controller.clear();
                    widget.onChanged('');
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class NotificationBellButton extends StatelessWidget {
  const NotificationBellButton({
    super.key,
    required this.unreadCount,
    required this.onPressed,
  });

  final int unreadCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Notifications',
      onPressed: onPressed,
      icon: Badge(
        isLabelVisible: unreadCount > 0,
        label: Text('$unreadCount'),
        child: const Icon(Icons.notifications_outlined),
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9));
  }
}
