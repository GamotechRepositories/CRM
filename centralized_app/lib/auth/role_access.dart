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
    if (user == null) return '';
    final d = user['designation'];
    if (d is Map) {
      final title = (d['title'] ?? d['name'])?.toString().trim();
      if (title != null && title.isNotEmpty) return title;
    }
    if (d is String && d.trim().isNotEmpty) return d.trim();
    final topTitle = (user['designationTitle'] ?? user['title'])?.toString().trim();
    if (topTitle != null && topTitle.isNotEmpty) return topTitle;
    return '';
  }

  static String accessRole(Map<String, dynamic>? user) {
    if (user == null) return '';
    final d = user['designation'];
    if (d is Map) {
      final role = (d['accessRole'] ?? d['role'])?.toString().trim().toLowerCase();
      if (role != null && role.isNotEmpty) return role;
    }
    if (d is String && d.trim().isNotEmpty) {
      final str = d.trim().toLowerCase();
      if (['hr', 'admin', 'manager', 'team_leader', 'employee'].contains(str)) return str;
    }
    final topRole = (user['accessRole'] ?? user['role'])?.toString().trim().toLowerCase();
    if (topRole != null && topRole.isNotEmpty) return topRole;

    // Fallback based on title
    final title = designationTitle(user).toLowerCase();
    if (title == 'admin' || title == 'technical lead') return 'admin';
    if (title.contains('hr') || title.contains('human resource')) return 'hr';
    if (title.contains('team lead') || title == 'team leader') return 'team_leader';
    if (title.contains('manager') || title.contains('operations')) return 'manager';

    return 'employee';
  }

  static bool isAdminUser(Map<String, dynamic>? user) {
    if (user == null) return false;
    final role = accessRole(user);
    if (role == 'admin' || role == 'technical_lead' || role == 'super_admin') return true;
    final title = designationTitle(user).toLowerCase();
    return title == 'admin' || title == 'technical lead' || title == 'super admin';
  }

  static bool isHrUser(Map<String, dynamic>? user) {
    if (user == null) return false;
    final role = accessRole(user);
    if (role == 'hr' || role == 'hr_manager') return true;
    final title = designationTitle(user).toLowerCase();
    return title.contains('hr') || title.contains('human resource');
  }

  static bool isTeamLeader(Map<String, dynamic>? user) {
    if (user == null) return false;
    if (isAdminUser(user)) return false;
    final role = accessRole(user);
    if (role == 'team_leader' || role == 'teamleader' || role == 'tl') return true;
    final title = designationTitle(user).toLowerCase();
    if (title == 'technical lead' || title == 'tech lead') return false;
    return title.contains('team lead') || title == 'team leader' || title.contains('tl');
  }

  static bool isManager(Map<String, dynamic>? user) {
    if (user == null) return false;
    if (isAdminUser(user) || isHrUser(user)) return false;
    final role = accessRole(user);
    if (role == 'manager') return true;
    final title = designationTitle(user).toLowerCase();
    if (['admin', 'technical lead', 'tech lead'].contains(title)) return false;
    return title.contains('manager') || title.contains('operations');
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

  static bool hasFullAccess(Map<String, dynamic>? user) {
    if (isAdminUser(user)) return true;
    final d = user?['designation'];
    if (d is Map) {
      final flag = d['permissions']?['hasFullAccess'];
      if (flag is bool) return flag;
    }
    if (isHrUser(user)) return true;
    final title = designationTitle(user).toLowerCase();
    return title == 'admin' || title.contains('hr') || title == 'technical lead';
  }

  static bool canViewProjects(Map<String, dynamic>? user) {
    if (isAdminUser(user) || isHrUser(user)) return true;
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
    final title = designationTitle(user).toLowerCase();
    if (allowed.contains(title)) return true;
    return title.contains('manager') || title.contains('lead') || title.contains('engineer');
  }

  static DashboardKind getDashboardKind(Map<String, dynamic>? user) {
    if (canViewAdminDashboard(user)) return DashboardKind.admin;
    if (isHrUser(user)) return DashboardKind.hr;
    if (isTeamLeader(user)) return DashboardKind.teamLeader;
    if (isManager(user)) return DashboardKind.manager;
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
    if (role == 'admin' || role == 'technical_lead' || role == 'super_admin') return true;
    final title = designationTitle(user).toLowerCase();
    return title == 'admin' || title == 'technical lead' || title == 'super admin';
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

  static bool isCooUser(Map<String, dynamic>? user) {
    if (user == null) return false;
    final title = designationTitle(user).toLowerCase();
    return title.contains('chief operating officer') || title == 'coo' || title.contains('coo');
  }

  /// Mirrors web `canApproveLeaveForUser`.
  static bool canApproveLeave(Map<String, dynamic>? user) {
    if (isAdminUser(user) || isHrUser(user) || isCooUser(user)) return true;
    return false;
  }

  static String leaveApprovalRole(Map<String, dynamic>? user) {
    if (isHrUser(user)) return 'hr';
    if (isCooUser(user)) return 'coo';
    if (isAdminUser(user)) return 'admin';
    return 'employee';
  }

  static bool canActOnLeaveStage(String role, String stage) {
    if (role == 'hr' || role == 'coo') return stage == 'hr' || stage == 'admin' || stage == 'team_leader';
    if (role == 'admin') return stage == 'admin' || stage == 'hr' || stage == 'team_leader';
    return false;
  }

  /// Mirrors web `isHRManager()` — admin or HR manager can view team attendance.
  static bool canViewTeamAttendance(Map<String, dynamic>? user) {
    if (isAdminUser(user) || isHrUser(user)) return true;
    return false;
  }

  /// Mirrors web `canManageLeadsForUser` — Admin, Sales Manager, or Sales Team Lead.
  static bool canManageLeads(Map<String, dynamic>? user) {
    if (user == null) return false;
    if (isAdminUser(user)) return true;

    final role = accessRole(user);
    final title = designationTitle(user).toLowerCase();
    final dept = (user['department'] ?? user['designation']?['department'] ?? '').toString().toLowerCase();
    final inSales = dept.contains('sales');

    if (title.contains('sales manager')) return true;
    if (title.contains('sales team lead') ||
        (inSales && (title.contains('team leader') || title.contains('team lead')))) {
      return true;
    }
    if (['admin', 'manager', 'team_leader'].contains(role) && inSales) return true;
    return false;
  }

  /// Checks if employee belongs to the Sales department.
  static bool isSalesDepartment(Map<String, dynamic>? user) {
    if (user == null) return false;
    final dept = (user['department'] ?? user['designation']?['department'] ?? '').toString().toLowerCase();
    final title = designationTitle(user).toLowerCase();
    final role = accessRole(user).toLowerCase();
    if (dept.contains('sales') || title.contains('sales') || role.contains('sales')) return true;
    return false;
  }

  /// Available for Sales employees, Team Leaders, Managers, Site Coordinators & Admins, and all STR users.
  static bool canViewTravelAndRouteMap(Map<String, dynamic>? user, {String? companyKey}) {
    if (user == null) return false;
    if (companyKey == 'salesTechReality') return true;
    final userCompany = (user['company'] ?? '').toString().toLowerCase();
    if (userCompany.contains('salestech') || userCompany.contains('sales_tech')) return true;
    if (isAdminUser(user) || isSiteCoordinatorUser(user) || isTeamLeader(user) || isManager(user)) return true;
    return isSalesDepartment(user);
  }

  /// Only Team Leaders (TLs), Managers, Admin, and Super Admin can assign tasks to other employees.
  /// Normal employees can only assign tasks to themselves.
  static bool canAssignTaskToOthers(Map<String, dynamic>? user) {
    if (user == null) return false;
    if (isAdminUser(user)) return true;
    if (isManager(user)) return true;
    if (isTeamLeader(user)) return true;
    final d = user['designation'];
    if (d is Map) {
      final flag = d['permissions']?['canAssignTask'];
      if (flag is bool) return flag;
    }
    return false;
  }
}
