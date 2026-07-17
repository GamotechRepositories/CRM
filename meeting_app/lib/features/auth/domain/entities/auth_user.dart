import 'package:equatable/equatable.dart';

import '../../../employees/domain/entities/employee.dart';

/// Top-level application role for multi-company access.
enum AppRole {
  /// Owns one or more companies; can switch between them.
  boss,

  /// Belongs to exactly one company (EA / Manager / Team Lead / Employee).
  member,
}

extension AppRoleX on AppRole {
  String get label => switch (this) {
    AppRole.boss => 'Boss',
    AppRole.member => 'Team Member',
  };

  static AppRole fromStorage(String? value) {
    if (value == 'boss') return AppRole.boss;
    return AppRole.member;
  }
}

/// Authenticated user with multi-company access metadata.
class AuthUser extends Equatable {
  const AuthUser({
    required this.id,
    required this.mobileNumber,
    required this.appRole,
    this.displayName,
    this.email,
    this.employeeId,
    this.employeeRole,
    this.homeCompanyId,
    this.roleLabel,
    this.tenants = const [],
  });

  final String id;
  final String mobileNumber;
  final String? displayName;
  final String? email;
  final AppRole appRole;

  /// Linked employee record when [appRole] is [AppRole.member].
  final String? employeeId;
  final EmployeeRole? employeeRole;

  /// The single company a member belongs to. Null for Boss.
  final String? homeCompanyId;

  /// Create Team job title (e.g. EA, Coordinator) from central admin.
  final String? roleLabel;

  /// CRM companies this user can operate across (tenant ids).
  final List<String> tenants;

  /// Portfolio ownership flag used by data repositories.
  /// Prefer [RoleResolver] + [PermissionSet] for authorization.
  bool get isBoss => appRole == AppRole.boss;
  bool get isMember => appRole == AppRole.member;

  @override
  List<Object?> get props => [
    id,
    mobileNumber,
    displayName,
    email,
    appRole,
    employeeId,
    employeeRole,
    homeCompanyId,
    roleLabel,
    tenants,
  ];
}
