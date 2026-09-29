import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_session.dart';
import '../auth/role_access.dart';
import '../navigation/app_bottom_bar.dart';
import '../navigation/app_nav.dart';
import '../navigation/app_sidebar.dart';
import '../navigation/sidebar_nav.dart';
import '../pages/app_page_factory.dart';
import '../screens/login_screen.dart';
import '../services/work_reminder_service.dart';

/// Logged-in shell: compact drawer sidebar + company-scoped page content.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  List<String> _pathHistory = [];

  String get _selectedPath {
    _initPathHistoryIfNeeded();
    return _pathHistory.last;
  }

  void _initPathHistoryIfNeeded() {
    final session = context.read<AuthSession>();
    final canonical = RoleAccess.dashboardPath(session.user);
    if (_pathHistory.isEmpty) {
      _pathHistory = [canonical];
    } else if (_pathHistory.length == 1 && RoleAccess.isDashboardPath(_pathHistory.first)) {
      _pathHistory = [canonical];
    }
  }

  @override
  void initState() {
    super.initState();
    _initPathHistoryIfNeeded();
    WidgetsBinding.instance.addObserver(this);
    // Let the dashboard's own requests go first; reminders are not urgent.
    _reminderStartTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) WorkReminderService.instance.start(context.read<AuthSession>());
    });
  }

  Timer? _reminderStartTimer;

  @override
  void dispose() {
    _reminderStartTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      WorkReminderService.instance.refresh(context.read<AuthSession>(), fresh: true);
    }
  }

  void _selectPath(String path) {
    if (path == _selectedPath) return;
    setState(() => _pathHistory.add(path));
  }

  /// Tabs replace history instead of stacking, so Back from any tab goes Home.
  void _selectTab(String path) {
    final home = RoleAccess.dashboardPath(context.read<AuthSession>().user);
    if (path == _selectedPath) return;
    setState(() => _pathHistory = path == home ? [home] : [home, path]);
  }

  void _goBack() {
    if (_pathHistory.length <= 1) return;
    setState(() => _pathHistory.removeLast());
  }

  Future<void> _logout() async {
    final session = context.read<AuthSession>();
    await session.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  /// Visited pages stay mounted so their state (and loaded data) survives
  /// navigation; only the selected one is visible.
  final Map<String, Widget> _cachedPages = {};

  @override
  Widget build(BuildContext context) {
    _initPathHistoryIfNeeded();
    final session = context.watch<AuthSession>();
    final nav = SidebarNav.build(sidebarContextForSession(session));
    final selectedPath = _selectedPath;
    final pageTitle = SidebarNav.labelForPath(nav, selectedPath) ?? 'CRM';

    _cachedPages.putIfAbsent(selectedPath, () => AppPageFactory.build(selectedPath));
    final paths = _cachedPages.keys.toList();
    final page = IndexedStack(
      index: paths.indexOf(selectedPath),
      sizing: StackFit.expand,
      children: [
        for (final path in paths)
          TickerMode(
            key: ValueKey(path),
            enabled: path == selectedPath,
            child: _cachedPages[path]!,
          ),
      ],
    );

    final tabs = bottomTabsFor(
      RoleAccess.getDashboardKind(session.user),
      nav,
      RoleAccess.dashboardPath(session.user),
    );
    final tabPaths = {for (final t in tabs) if (t.path != null) t.path!};
    final onTabPage = tabPaths.contains(selectedPath);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    // Like iOS, the tab bar only shows on tab pages; pages opened from More
    // get a back button instead.
    final showBottomBar = onTabPage && !keyboardOpen;
    // Chat pins a composer to the bottom, so it keeps the bar's space reserved.
    final contentUnderBar = showBottomBar && selectedPath != '/module/chat';
    final showBack = _pathHistory.length > 1 && !onTabPage;

    return PopScope(
      canPop: _pathHistory.length <= 1,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        extendBody: contentUnderBar,
        appBar: AppBar(
          toolbarHeight: 42,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0F172A),
          automaticallyImplyLeading: false,
          leading: showBack
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, size: 20),
                  onPressed: _goBack,
                )
              : null,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pageTitle,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              Text(
                session.company?.shortName ?? '',
                style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
        body: AppNavScope(
          goTo: _selectPath,
          child: page,
        ),
        bottomNavigationBar: showBottomBar
            ? AppBottomBar(
                tabs: tabs,
                selectedIndex: tabs.indexWhere((t) => t.path == selectedPath),
                onTap: (i) => _onTabTap(tabs[i], session, nav, tabPaths),
              )
            : null,
      ),
    );
  }

  void _onTabTap(BottomTab tab, AuthSession session, List<SidebarEntry> nav, Set<String> tabPaths) {
    if (!tab.isMore) {
      _selectTab(tab.path!);
      return;
    }
    showMoreSheet(
      context: context,
      session: session,
      nav: nav,
      tabPaths: tabPaths,
      selectedPath: _selectedPath,
      onSelect: _selectPath,
      onSettings: () => _selectPath('/settings'),
      onLogout: _logout,
    );
  }
}
