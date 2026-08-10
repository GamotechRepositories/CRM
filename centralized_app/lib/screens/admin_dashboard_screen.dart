import 'package:flutter/material.dart';

import '../pages/dashboard_page.dart';

/// @deprecated Use [AppShell] with sidebar navigation instead.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      body: DashboardPage(),
    );
  }
}
