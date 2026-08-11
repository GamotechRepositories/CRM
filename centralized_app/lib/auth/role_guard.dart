import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth_session.dart';
import 'role_access.dart';
import '../pages/placeholder_page.dart';

class RoleGuard extends StatelessWidget {
  const RoleGuard({
    super.key,
    required this.path,
    required this.child,
  });

  final String path;
  final Widget child;

  static const _fullAccessPaths = {
    '/admin-dashboard',
    '/clients',
    '/add-client',
    '/employees',
    '/add-employee',
    '/salaries',
    '/payroll',
    '/billings',
    '/invoices',
    '/expenses',
    '/revenue',
    '/module/gst',
    '/gst',
    '/campaigns',
    '/reports',
    '/company-profile',
    '/module/departments',
    '/departments',
    '/module/designations',
    '/designations',
    '/module/assets',
    '/assets',
    '/module/milestones',
    '/milestones',
  };

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthSession>();
    final user = session.user;

    // Full access users (Admin, HR Manager, Technical Lead) can access everything
    if (RoleAccess.hasFullAccess(user)) {
      return child;
    }

    // Allow user to access their own profile
    final ownId = session.userId;
    if (ownId.isNotEmpty && path.contains('/employees/$ownId/profile')) {
      return child;
    }

    // Check if current route requires full access
    final isFullAccessRequired = _fullAccessPaths.any((p) => path == p || path.startsWith('$p/'));
    if (isFullAccessRequired) {
      return PlaceholderPage(
        title: 'Access Restricted',
        subtitle: 'You do not have permission to view this section. Please contact your system administrator.',
        webPath: path,
      );
    }

    // Check project viewing permissions
    if (path == '/projects' && !RoleAccess.canViewProjects(user)) {
      return PlaceholderPage(
        title: 'Access Restricted',
        subtitle: 'You do not have permission to view company projects.',
        webPath: path,
      );
    }

    return child;
  }
}
