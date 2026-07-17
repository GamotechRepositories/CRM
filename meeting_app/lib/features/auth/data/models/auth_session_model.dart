import '../../domain/entities/auth_session.dart';
import '../../domain/entities/auth_user.dart';
import '../../../employees/domain/entities/employee.dart';

class AuthUserModel {
  const AuthUserModel({
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
  final String appRole;
  final String? employeeId;
  final String? employeeRole;
  final String? homeCompanyId;
  final String? roleLabel;
  final List<String> tenants;

  factory AuthUserModel.fromJson(Map<String, dynamic> json) {
    final rawTenants = json['tenants'];
    final tenants = rawTenants is List
        ? rawTenants.map((e) => e.toString()).toList()
        : <String>[];
    return AuthUserModel(
      id: json['id'] as String,
      mobileNumber: json['mobileNumber'] as String,
      displayName: json['displayName'] as String?,
      email: json['email'] as String?,
      appRole: json['appRole'] as String? ?? 'boss',
      employeeId: json['employeeId'] as String?,
      employeeRole: json['employeeRole'] as String?,
      homeCompanyId: json['homeCompanyId'] as String?,
      roleLabel: json['roleLabel'] as String?,
      tenants: tenants,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'mobileNumber': mobileNumber,
    'displayName': displayName,
    'email': email,
    'appRole': appRole,
    'employeeId': employeeId,
    'employeeRole': employeeRole,
    'homeCompanyId': homeCompanyId,
    'roleLabel': roleLabel,
    'tenants': tenants,
  };

  AuthUser toEntity() => AuthUser(
    id: id,
    mobileNumber: mobileNumber,
    displayName: displayName,
    email: email,
    appRole: AppRoleX.fromStorage(appRole),
    employeeId: employeeId,
    employeeRole: employeeRole == null
        ? null
        : EmployeeRoleX.fromStorage(employeeRole!),
    homeCompanyId: homeCompanyId,
    roleLabel: roleLabel,
    tenants: tenants,
  );

  factory AuthUserModel.fromEntity(AuthUser user) => AuthUserModel(
    id: user.id,
    mobileNumber: user.mobileNumber,
    displayName: user.displayName,
    email: user.email,
    appRole: user.appRole.name,
    employeeId: user.employeeId,
    employeeRole: user.employeeRole?.name,
    homeCompanyId: user.homeCompanyId,
    roleLabel: user.roleLabel,
    tenants: user.tenants,
  );
}

class AuthSessionModel {
  const AuthSessionModel({
    required this.user,
    required this.token,
    required this.expiresAt,
  });

  final AuthUserModel user;
  final String token;
  final DateTime expiresAt;

  factory AuthSessionModel.fromJson(Map<String, dynamic> json) {
    return AuthSessionModel(
      user: AuthUserModel.fromJson(
        Map<String, dynamic>.from(json['user'] as Map),
      ),
      token: json['token'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'user': user.toJson(),
    'token': token,
    'expiresAt': expiresAt.toIso8601String(),
  };

  AuthSession toEntity() =>
      AuthSession(user: user.toEntity(), token: token, expiresAt: expiresAt);

  factory AuthSessionModel.fromEntity(AuthSession session) => AuthSessionModel(
    user: AuthUserModel.fromEntity(session.user),
    token: session.token,
    expiresAt: session.expiresAt,
  );
}
