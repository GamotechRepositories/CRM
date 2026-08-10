/// Role helpers mirroring web `dashboardRoutes` / `authPermissions`.
enum DashboardKind {
  admin,
  hr,
  manager,
  teamLeader,
  siteCoordinator,
  employee,
}

class RoleAccess {
  RoleAccess._();

  static String _normalizeKey(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');

  static String designationTitle(Map<String, dynamic>? user) {
    final d = user?['designation'];
    if (d is Map) {
      return (d['title'] ?? d['name'] ?? '').toString().trim();
    }
    return (d ?? '').toString().trim();
  }

  static String accessRole(Map<String, dynamic>? user) {
    final d = user?['designation'];
    if (d is Map) return (d['accessRole'] ?? '').toString().trim().toLowerCase();
    return '';
  }

  static bool isAdminUser(Map<String, dynamic>? user) {
    if (user == null) return false;
    final role = accessRole(user);
    if (role == 'admin') return true;
    return designationTitle(user).toLowerCase() == 'admin';
  }

  static bool hasFullAccess(Map<String, dynamic>? user) {
    if (isAdminUser(user)) return true;
    final d = user?['designation'];
    if (d is Map) {
      final flag = d['permissions']?['hasFullAccess'];
      if (flag is bool) return flag;
    }
    final title = designationTitle(user).toLowerCase();
    return title == 'admin' || title == 'hr manager' || title == 'technical lead';
  }

  static bool canViewProjects(Map<String, dynamic>? user) {
    if (isAdminUser(user)) return true;
    final d = user?['designation'];
    if (d is Map) {
      final flag = d['permissions']?['canViewProjects'];
      if (flag is bool) return flag;
    }
    const allowed = {
      'admin',
      'hr manager',
      'technical lead',
      'social media manager',
      'product manager',
      'senior software engineer',
      'project manager',
      'engineering manager',
    };
    return allowed.contains(designationTitle(user).toLowerCase());
  }

  static bool isTeamLeader(Map<String, dynamic>? user) {
    if (user == null) return false;
    final role = accessRole(user);
    if (role == 'team_leader') return true;
    final title = designationTitle(user).toLowerCase();
    if (title == 'technical lead') return false;
    return title.contains('team lead') || title == 'team leader';
  }

  /// Site Co-ordinator / Site Coordinator / Site Reliability Engineer.
  static bool isSiteCoordinatorUser(Map<String, dynamic>? user) {
    if (user == null) return false;
    final role = accessRole(user);
    if (role == 'site_coordinator') return true;
    final key = _normalizeKey(designationTitle(user));
    if (key.contains('sitecoordinator')) return true;
    if (key.contains('sitereliabilityengineer')) return true;
    if (key.contains('sitereliability') && key.contains('engineer')) return true;
    return false;
  }

  static bool _isManagerTitle(String title) {
    final t = title.toLowerCase();
    if (t == 'hr manager') return false;
    if (['admin', 'technical lead'].contains(t)) return false;
    if (t.contains('manager')) return true;
    if (t.contains('operations')) return true;
    return false;
  }

  static DashboardKind getDashboardKind(Map<String, dynamic>? user) {
    if (canViewAdminDashboard(user)) return DashboardKind.admin;
    final role = accessRole(user);
    final title = designationTitle(user).toLowerCase();
    if (role == 'hr' || title == 'hr manager') return DashboardKind.hr;
    if (isTeamLeader(user)) return DashboardKind.teamLeader;
    if (role == 'manager' || _isManagerTitle(title)) return DashboardKind.manager;
    if (isSiteCoordinatorUser(user)) return DashboardKind.siteCoordinator;
    return DashboardKind.employee;
  }

  static List<String>? sidebarSections(Map<String, dynamic>? user) {
    if (hasFullAccess(user)) return null;
    final raw = user?['access']?['sidebarSections'];
    if (raw is List && raw.isNotEmpty) {
      return raw.map((e) => e.toString()).toList();
    }
    return null;
  }

  static bool canViewAdminDashboard(Map<String, dynamic>? user) {
    if (user == null) return false;
    final role = accessRole(user);
    if (role == 'admin' || role == 'technical_lead') return true;
    final title = designationTitle(user).toLowerCase();
    return title == 'admin' || title == 'technical lead';
  }

  static String dashboardPath(Map<String, dynamic>? user) {
    switch (getDashboardKind(user)) {
      case DashboardKind.admin:
        return '/admin-dashboard';
      case DashboardKind.hr:
        return '/hr-dashboard';
      case DashboardKind.teamLeader:
        return '/team-leader-dashboard';
      case DashboardKind.manager:
        return '/manager-dashboard';
      case DashboardKind.siteCoordinator:
        return '/site-coordinator-dashboard';
      case DashboardKind.employee:
        return '/dashboard';
    }
  }

  static bool isDashboardPath(String path) {
    return const {
      '/dashboard',
      '/admin-dashboard',
      '/hr-dashboard',
      '/manager-dashboard',
      '/team-leader-dashboard',
      '/site-coordinator-dashboard',
    }.contains(path);
  }

  /// Mirrors web `canApproveLeaveForUser`.
  static bool canApproveLeave(Map<String, dynamic>? user) {
    if (isAdminUser(user)) return true;
    final role = accessRole(user);
    if (['team_leader', 'manager', 'hr'].contains(role)) return true;
    final title = designationTitle(user).toLowerCase();
    if (title.contains('team lead') || title.contains('manager')) return true;
    final d = user?['designation'];
    if (d is Map) {
      final flag = d['permissions']?['canApproveLeave'];
      if (flag is bool) return flag;
    }
    const allowed = {
      'admin',
      'hr manager',
      'project manager',
      'technical lead',
      'engineering manager',
      'product manager',
      'senior software engineer',
    };
    return allowed.contains(title);
  }

  static String leaveApprovalRole(Map<String, dynamic>? user) {
    final role = accessRole(user);
    final title = designationTitle(user).toLowerCase();
    if (title == 'team leader' || title.contains('team lead')) return 'team_leader';
    if (title == 'hr manager' || title == 'hr') return 'hr';
    if (title == 'admin') return 'admin';
    if (title.contains('manager')) return 'manager';
    if (role.isNotEmpty) return role;
    return 'employee';
  }

  static bool canActOnLeaveStage(String role, String stage) {
    if (stage == 'team_leader') return role == 'team_leader' || role == 'manager';
    if (stage == 'hr') return role == 'hr';
    if (stage == 'admin') return role == 'admin';
    return false;
  }

  /// Mirrors web `isHRManager()` — admin or HR manager can view team attendance.
  static bool canViewTeamAttendance(Map<String, dynamic>? user) {
    if (isAdminUser(user)) return true;
    return designationTitle(user).toLowerCase() == 'hr manager';
  }
}
