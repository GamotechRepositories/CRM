import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/crm_companies.dart';
import '../../../../core/error/result.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/network/api_health_service.dart';
import '../../../../core/rbac/rbac_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/layout/app_scaffold.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../meetings/presentation/providers/meeting_providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final colorScheme = context.colorScheme;
    final healthAsync = ref.watch(apiHealthProvider);
    final permissions = ref.watch(permissionSetProvider);
    final user = ref.watch(authSessionProvider).session?.user;
    final meetings = ref.watch(meetingsControllerProvider).meetings;
    final isBoss = !permissions.canCreateMeeting;
    final roleLabel =
        user?.roleLabel?.trim().isNotEmpty == true
            ? user!.roleLabel!
            : (isBoss ? 'Boss' : 'Team');
    final companies = CrmCompanies.forTenantIds(user?.tenants ?? const []);
    final now = DateTime.now();
    final upcomingCount = meetings.where((m) => m.startAt.isAfter(now)).length;
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayCount = meetings
        .where(
          (m) =>
              !m.startAt.isBefore(todayStart) &&
              m.startAt.isBefore(todayStart.add(const Duration(days: 1))),
        )
        .length;

    return AppScaffold(
      maxContentWidth: 640,
      padFloatingNav: true,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Profile
          AppCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: colorScheme.primary,
                  child: Text(
                    (user?.displayName ?? 'U').trim().isNotEmpty
                        ? (user!.displayName!.trim()[0].toUpperCase())
                        : 'U',
                    style: context.textTheme.titleLarge?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? 'User',
                        style: context.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: (isBoss ? AppColors.secondary : AppColors.primary)
                              .withValues(alpha: 0.12),
                          borderRadius: AppRadius.fullAll,
                        ),
                        child: Text(
                          roleLabel,
                          style: context.textTheme.labelMedium?.copyWith(
                            color: isBoss
                                ? AppColors.secondary
                                : AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (user?.email != null &&
                          user!.email!.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _InfoLine(
                          icon: Icons.email_outlined,
                          text: user.email!,
                        ),
                      ],
                      if (user != null &&
                          user.mobileNumber.isNotEmpty &&
                          user.mobileNumber != '0000000000') ...[
                        const SizedBox(height: 6),
                        _InfoLine(
                          icon: Icons.phone_outlined,
                          text: user.mobileNumber,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(),
          const SizedBox(height: AppSpacing.md),

          // Quick snapshot
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your schedule snapshot',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _MiniStat(
                        label: 'Total',
                        value: '${meetings.length}',
                        icon: Icons.event_note_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniStat(
                        label: 'Today',
                        value: '$todayCount',
                        icon: Icons.today_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniStat(
                        label: 'Upcoming',
                        value: '$upcomingCount',
                        icon: Icons.upcoming_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(delay: 30.ms),
          const SizedBox(height: AppSpacing.md),

          // Access / how it works
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isBoss ? 'Boss access' : 'Team access',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ..._accessBullets(isBoss).map(
                  (text) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            text,
                            style: context.textTheme.bodyMedium?.copyWith(
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 60.ms),
          const SizedBox(height: AppSpacing.md),

          // Companies
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isBoss ? 'Companies in portfolio' : 'Companies you can use',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isBoss
                      ? 'Meetings can be tagged to any of these companies.'
                      : 'When creating a meeting, pick which company it belongs to.',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (companies.isEmpty)
                  Text(
                    'No companies assigned. Ask admin to update Create Team access.',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.error,
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: companies
                        .map(
                          (c) => Chip(
                            avatar: Icon(
                              Icons.business_outlined,
                              size: 16,
                              color: colorScheme.primary,
                            ),
                            label: Text(c.name),
                            visualDensity: VisualDensity.compact,
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ).animate().fadeIn(delay: 90.ms),
          const SizedBox(height: AppSpacing.md),

          // Theme
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Appearance',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose how the app looks on this device.',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System'),
                      icon: Icon(Icons.brightness_auto_rounded, size: 18),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode_rounded, size: 18),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode_rounded, size: 18),
                    ),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (selection) {
                    ref
                        .read(themeModeProvider.notifier)
                        .setThemeMode(selection.first);
                  },
                  showSelectedIcon: false,
                ),
              ],
            ),
          ).animate().fadeIn(delay: 120.ms),
          const SizedBox(height: AppSpacing.md),

          // Connection
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connection',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                healthAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => Text(
                    'Could not reach server',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.error,
                    ),
                  ),
                  data: (result) => switch (result) {
                    Success() => const _InfoLine(
                      icon: Icons.check_circle_rounded,
                      text: 'Connected to meeting server',
                      color: AppColors.success,
                    ),
                    Error(:final failure) => _InfoLine(
                      icon: Icons.error_outline_rounded,
                      text: failure.message,
                      color: colorScheme.error,
                    ),
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Test connection',
                  icon: Icons.wifi_tethering,
                  variant: AppButtonVariant.outlined,
                  onPressed: () => ref.invalidate(apiHealthProvider),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 150.ms),
          const SizedBox(height: AppSpacing.md),

          // About
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppConstants.appName,
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppConstants.appTagline,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Version 1.0.0',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Accounts are managed from Create Team in central admin.',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 180.ms),
          const SizedBox(height: AppSpacing.lg),

          AppButton(
            label: 'Sign out',
            icon: Icons.logout_rounded,
            variant: AppButtonVariant.outlined,
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sign out?'),
                  content: const Text(
                    'You will need your Create Team email and password to sign in again.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await ref.read(authSessionProvider.notifier).logout();
              }
            },
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  List<String> _accessBullets(bool isBoss) {
    if (isBoss) {
      return const [
        'View all meetings created for you by the team.',
        'Open any meeting to see agenda, company, time, and who created it.',
        'You cannot create or edit meetings — your team handles scheduling.',
      ];
    }
    return const [
      'Create and edit meetings that you scheduled for the Boss.',
      'Always pick the company the meeting belongs to.',
      'Boss sees every meeting on their Home and Meetings screens.',
    ];
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.text,
    this.color,
  });

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 16, color: c),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: context.textTheme.bodyMedium?.copyWith(color: c),
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: AppRadius.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: scheme.primary),
          const SizedBox(height: 6),
          Text(
            value,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: context.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
