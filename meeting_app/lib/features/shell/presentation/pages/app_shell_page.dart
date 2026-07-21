import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/rbac/rbac_providers.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/router/shell_nav_catalog.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../meetings/domain/entities/meeting.dart';
import '../../../meetings/presentation/providers/meeting_providers.dart';
import '../widgets/flipkart_bottom_nav.dart';
import '../widgets/flipkart_nav_item.dart';
import '../widgets/shell_bottom_insets.dart';
import '../widgets/tab_scroll_registry.dart';

/// Branch navigator keys — shared with [app_router] for canPop checks.
abstract final class ShellNavigatorKeys {
  static final home = GlobalKey<NavigatorState>(debugLabel: 'shell-home');
  static final meetings =
      GlobalKey<NavigatorState>(debugLabel: 'shell-meetings');
  static final settings =
      GlobalKey<NavigatorState>(debugLabel: 'shell-settings');

  static List<GlobalKey<NavigatorState>> get all => [
        home,
        meetings,
        settings,
      ];
}

/// No auth-gated shell tabs (login is required before shell).
const Set<int> kAuthGatedBranchIndices = <int>{};

class AppShellPage extends ConsumerStatefulWidget {
  const AppShellPage({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends ConsumerState<AppShellPage> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
    );
  }

  int _todayMeetingCount(List<Meeting> meetings) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return meetings
        .where((m) => !m.startAt.isBefore(start) && m.startAt.isBefore(end))
        .length;
  }

  Future<void> _onTabTap({
    required int visibleIndex,
    required List<ShellDestinationSpec> visible,
    required bool isAuthenticated,
  }) async {
    final dest = visible[visibleIndex];
    final branch = dest.branchIndex;

    if (!isAuthenticated && kAuthGatedBranchIndices.contains(branch)) {
      if (mounted) context.go(RoutePaths.login);
      return;
    }

    final isReselect = branch == widget.navigationShell.currentIndex;

    if (isReselect) {
      await TabScrollRegistry.scrollToTop(visibleIndex);
      widget.navigationShell.goBranch(branch, initialLocation: true);
      return;
    }

    widget.navigationShell.goBranch(branch, initialLocation: false);
  }

  @override
  Widget build(BuildContext context) {
    // Keep Socket.IO connected for live meeting updates across all tabs.
    ref.watch(meetingRealtimeSyncProvider);

    final permissions = ref.watch(permissionSetProvider);
    final visible = ShellNavCatalog.visibleFor(permissions.can);
    final user = ref.watch(authSessionProvider).session?.user;
    final isAuthenticated = ref.watch(authSessionProvider).isAuthenticated;
    final meetings = ref.watch(
      meetingsControllerProvider.select((s) => s.meetings),
    );
    final badgeCount = _todayMeetingCount(meetings);

    final selectedVisibleIndex = visible.indexWhere(
      (d) => d.branchIndex == widget.navigationShell.currentIndex,
    );

    if (visible.isNotEmpty && selectedVisibleIndex < 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.navigationShell.goBranch(visible.first.branchIndex);
      });
    }

    final name = user?.displayName?.trim() ?? '';
    final accountInitial = name.isNotEmpty ? name[0].toUpperCase() : null;

    final items = visible
        .map(
          (d) => FlipkartNavItem(
            label: d.label,
            icon: d.icon,
            activeIcon: d.activeIcon,
            showBadge: d.showBadge,
            branchIndex: d.branchIndex,
          ),
        )
        .toList();

    final currentVisible =
        selectedVisibleIndex < 0 ? 0 : selectedVisibleIndex;

    return Scaffold(
      extendBody: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          widget.navigationShell,
          if (visible.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: FlipkartBottomNav(
                items: items,
                currentIndex: currentVisible,
                badgeCount: badgeCount,
                accountInitial: accountInitial,
                onTap: (index) => _onTabTap(
                  visibleIndex: index,
                  visible: visible,
                  isAuthenticated: isAuthenticated,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Expose inset helper through shell for list pages.
double shellBottomInset(BuildContext context) => ShellBottomInsets.of(context);
