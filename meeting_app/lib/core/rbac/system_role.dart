import '../../features/auth/domain/entities/auth_user.dart';
import '../../features/employees/domain/entities/employee.dart';

/// Canonical application roles used by RBAC.
enum SystemRole {
  boss,
  meetingCoordinator,
  executiveAssistant,
  manager,
  teamLead,
  employee,
}

extension SystemRoleX on SystemRole {
  String get label => switch (this) {
    SystemRole.boss => 'Boss',
    SystemRole.meetingCoordinator => 'Meeting Coordinator',
    SystemRole.executiveAssistant => 'Executive Assistant',
    SystemRole.manager => 'Manager',
    SystemRole.teamLead => 'Team Lead',
    SystemRole.employee => 'Employee',
  };
}

/// Single place that maps auth identity → [SystemRole].
///
/// This is the only module allowed to interpret role identity.
abstract final class RoleResolver {
  static SystemRole fromAuthUser(AuthUser user) {
    if (user.appRole == AppRole.boss) return SystemRole.boss;

    return switch (user.employeeRole) {
      EmployeeRole.boss => SystemRole.boss,
      EmployeeRole.meetingCoordinator => SystemRole.meetingCoordinator,
      EmployeeRole.executiveAssistant => SystemRole.executiveAssistant,
      EmployeeRole.manager => SystemRole.manager,
      EmployeeRole.teamLead => SystemRole.teamLead,
      EmployeeRole.employee || null => SystemRole.employee,
    };
  }
}
