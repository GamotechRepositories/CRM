import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum EmployeeRole { boss, executiveAssistant, manager, teamLead, employee }

enum EmployeeStatus { active, inactive }

extension EmployeeRoleX on EmployeeRole {
  String get label => switch (this) {
    EmployeeRole.boss => 'Boss',
    EmployeeRole.executiveAssistant => 'Executive Assistant',
    EmployeeRole.manager => 'Manager',
    EmployeeRole.teamLead => 'Team Lead',
    EmployeeRole.employee => 'Employee',
  };

  static EmployeeRole fromStorage(String value) {
    return EmployeeRole.values.firstWhere(
      (e) => e.name == value,
      orElse: () => EmployeeRole.employee,
    );
  }
}

/// Domain entity for an employee belonging to a company.
class Employee extends Equatable {
  const Employee({
    required this.id,
    required this.companyId,
    required this.name,
    required this.mobile,
    required this.email,
    required this.department,
    required this.designation,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.reportingManagerId,
    this.avatarColorValue = 0xFF1D4ED8,
    this.avatarIcon = 'person',
  });

  final String id;
  final String companyId;
  final String name;
  final String mobile;
  final String email;
  final String department;
  final String designation;
  final EmployeeRole role;
  final String? reportingManagerId;
  final EmployeeStatus status;
  final int avatarColorValue;
  final String avatarIcon;
  final DateTime createdAt;
  final DateTime updatedAt;

  Color get avatarColor => Color(avatarColorValue);
  bool get isActive => status == EmployeeStatus.active;
  String get initial => name.isNotEmpty ? name.trim()[0].toUpperCase() : '?';

  Employee copyWith({
    String? id,
    String? companyId,
    String? name,
    String? mobile,
    String? email,
    String? department,
    String? designation,
    EmployeeRole? role,
    String? reportingManagerId,
    EmployeeStatus? status,
    int? avatarColorValue,
    String? avatarIcon,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearManager = false,
  }) {
    return Employee(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      department: department ?? this.department,
      designation: designation ?? this.designation,
      role: role ?? this.role,
      reportingManagerId: clearManager
          ? null
          : (reportingManagerId ?? this.reportingManagerId),
      status: status ?? this.status,
      avatarColorValue: avatarColorValue ?? this.avatarColorValue,
      avatarIcon: avatarIcon ?? this.avatarIcon,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    companyId,
    name,
    mobile,
    email,
    department,
    designation,
    role,
    reportingManagerId,
    status,
    avatarColorValue,
    avatarIcon,
    createdAt,
    updatedAt,
  ];
}

abstract final class EmployeeDepartments {
  static const List<String> all = [
    'Executive',
    'Operations',
    'Sales',
    'Marketing',
    'Engineering',
    'HR',
    'Finance',
    'Support',
    'Other',
  ];
}

abstract final class EmployeeDesignations {
  static const List<String> all = [
    'Chief Executive',
    'Executive Assistant',
    'General Manager',
    'Department Manager',
    'Team Lead',
    'Senior Associate',
    'Associate',
    'Intern',
  ];
}

abstract final class EmployeeAvatarIcons {
  static const Map<String, IconData> icons = {
    'person': Icons.person_rounded,
    'badge': Icons.badge_rounded,
    'engineering': Icons.engineering_rounded,
    'support': Icons.support_agent_rounded,
    'finance': Icons.account_balance_wallet_rounded,
    'sales': Icons.trending_up_rounded,
    'hr': Icons.diversity_3_rounded,
    'star': Icons.star_rounded,
  };

  static IconData resolve(String key) => icons[key] ?? Icons.person_rounded;
}

abstract final class EmployeeAvatarColors {
  static const List<Color> presets = [
    Color(0xFF1D4ED8),
    Color(0xFF0F766E),
    Color(0xFF7C3AED),
    Color(0xFFBE123C),
    Color(0xFFC2410C),
    Color(0xFF047857),
    Color(0xFF0369A1),
    Color(0xFF4F46E5),
  ];
}
