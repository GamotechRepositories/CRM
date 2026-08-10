import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_session.dart';
import '../navigation/app_shell.dart';
import 'login_screen.dart';

/// Post-login entry — sidebar shell for every role/company.
class AppHome extends StatelessWidget {
  const AppHome({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthSession>();
    if (!session.isLoggedIn) return const LoginScreen();
    return const AppShell();
  }
}
