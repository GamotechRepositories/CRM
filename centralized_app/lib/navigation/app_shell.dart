import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_session.dart';
import '../auth/role_access.dart';
import '../navigation/app_nav.dart';
import '../navigation/app_sidebar.dart';
import '../navigation/sidebar_nav.dart';
import '../pages/app_page_factory.dart';
import '../screens/login_screen.dart';

/// Logged-in shell: compact drawer sidebar + company-scoped page content.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  List<String> _pathHistory = [];

  String get _selectedPath {
    _initPathHistoryIfNeeded();
    return _pathHistory.last;
  }

  void _initPathHistoryIfNeeded() {
    if (_pathHistory.isNotEmpty) return;
    final session = context.read<AuthSession>();
    _pathHistory = [RoleAccess.dashboardPath(session.user)];
  }

  @override
  void initState() {
    super.initState();
    _initPathHistoryIfNeeded();
  }

  void _selectPath(String path) {
    if (path == _selectedPath) return;
    setState(() => _pathHistory.add(path));
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

  @override
  Widget build(BuildContext context) {
    _initPathHistoryIfNeeded();
    final session = context.watch<AuthSession>();
    final nav = SidebarNav.build(sidebarContextForSession(session));
    final pageTitle = SidebarNav.labelForPath(nav, _selectedPath) ?? 'CRM';

    return PopScope(
      canPop: _pathHistory.length <= 1,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          toolbarHeight: 42,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0F172A),
          leading: _pathHistory.length > 1
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
        drawer: AppSidebar(
          nav: nav,
          selectedPath: _selectedPath,
          onSelect: _selectPath,
          onSettings: () => _selectPath('/settings'),
          onLogout: _logout,
        ),
        body: AppNavScope(
          goTo: _selectPath,
          child: KeyedSubtree(
            key: ValueKey(_selectedPath),
            child: AppPageFactory.build(_selectedPath),
          ),
        ),
      ),
    );
  }
}
