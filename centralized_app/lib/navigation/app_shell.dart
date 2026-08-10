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
  late String _selectedPath;

  @override
  void initState() {
    super.initState();
    final session = context.read<AuthSession>();
    _selectedPath = RoleAccess.dashboardPath(session.user);
  }

  void _selectPath(String path) {
    setState(() => _selectedPath = path);
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
    final session = context.watch<AuthSession>();
    final nav = SidebarNav.build(sidebarContextForSession(session));
    final pageTitle = SidebarNav.labelForPath(nav, _selectedPath) ?? 'CRM';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        toolbarHeight: 42,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
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
    );
  }
}
