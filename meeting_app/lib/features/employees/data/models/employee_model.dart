import '../../domain/entities/employee.dart';

class EmployeeModel {
  const EmployeeModel({
    required this.id,
    required this.companyId,
    required this.name,
    required this.mobile,
    required this.email,
    required this.department,
    required this.designation,
    required this.role,
    required this.status,
    required this.avatarColorValue,
    required this.avatarIcon,
    required this.createdAt,
    required this.updatedAt,
    this.reportingManagerId,
  });

  final String id;
  final String companyId;
  final String name;
  final String mobile;
  final String email;
  final String department;
  final String designation;
  final String role;
  final String? reportingManagerId;
  final String status;
  final int avatarColorValue;
  final String avatarIcon;
  final String createdAt;
  final String updatedAt;

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    return EmployeeModel(
      id: json['id'] as String,
      companyId: json['companyId'] as String,
      name: json['name'] as String,
      mobile: json['mobile'] as String? ?? '',
      email: json['email'] as String? ?? '',
      department: json['department'] as String? ?? 'Other',
      designation: json['designation'] as String? ?? 'Associate',
      role: json['role'] as String? ?? EmployeeRole.employee.name,
      reportingManagerId: json['reportingManagerId'] as String?,
      status: json['status'] as String? ?? 'active',
      avatarColorValue: json['avatarColorValue'] as int? ?? 0xFF1D4ED8,
      avatarIcon: json['avatarIcon'] as String? ?? 'person',
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'companyId': companyId,
    'name': name,
    'mobile': mobile,
    'email': email,
    'department': department,
    'designation': designation,
    'role': role,
    'reportingManagerId': reportingManagerId,
    'status': status,
    'avatarColorValue': avatarColorValue,
    'avatarIcon': avatarIcon,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  Employee toEntity() => Employee(
    id: id,
    companyId: companyId,
    name: name,
    mobile: mobile,
    email: email,
    department: department,
    designation: designation,
    role: EmployeeRoleX.fromStorage(role),
    reportingManagerId: reportingManagerId,
    status: status == 'inactive'
        ? EmployeeStatus.inactive
        : EmployeeStatus.active,
    avatarColorValue: avatarColorValue,
    avatarIcon: avatarIcon,
    createdAt: DateTime.parse(createdAt),
    updatedAt: DateTime.parse(updatedAt),
  );

  factory EmployeeModel.fromEntity(Employee e) => EmployeeModel(
    id: e.id,
    companyId: e.companyId,
    name: e.name,
    mobile: e.mobile,
    email: e.email,
    department: e.department,
    designation: e.designation,
    role: e.role.name,
    reportingManagerId: e.reportingManagerId,
    status: e.status == EmployeeStatus.inactive ? 'inactive' : 'active',
    avatarColorValue: e.avatarColorValue,
    avatarIcon: e.avatarIcon,
    createdAt: e.createdAt.toIso8601String(),
    updatedAt: e.updatedAt.toIso8601String(),
  );
}
