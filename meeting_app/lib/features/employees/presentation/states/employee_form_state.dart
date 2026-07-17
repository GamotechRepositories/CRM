import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/employee.dart';

enum EmployeeFormMode { create, edit }

enum EmployeeFormStatus { initial, loading, success, error }

class EmployeeFormState extends Equatable {
  const EmployeeFormState({
    required this.mode,
    required this.companyId,
    this.status = EmployeeFormStatus.initial,
    this.employeeId,
    this.name = '',
    this.mobile = '',
    this.email = '',
    this.department = 'Operations',
    this.designation = 'Associate',
    this.role = EmployeeRole.employee,
    this.reportingManagerId,
    this.employeeStatus = EmployeeStatus.active,
    this.avatarColorValue = 0xFF1D4ED8,
    this.avatarIcon = 'person',
    this.createdAt,
    this.errorMessage,
    this.managerOptions = const [],
  });

  final EmployeeFormMode mode;
  final EmployeeFormStatus status;
  final String companyId;
  final String? employeeId;
  final String name;
  final String mobile;
  final String email;
  final String department;
  final String designation;
  final EmployeeRole role;
  final String? reportingManagerId;
  final EmployeeStatus employeeStatus;
  final int avatarColorValue;
  final String avatarIcon;
  final DateTime? createdAt;
  final String? errorMessage;
  final List<Employee> managerOptions;

  bool get isLoading => status == EmployeeFormStatus.loading;
  bool get isValid =>
      name.trim().isNotEmpty &&
      mobile.trim().isNotEmpty &&
      email.trim().isNotEmpty &&
      department.trim().isNotEmpty &&
      designation.trim().isNotEmpty;

  Color get avatarColor => Color(avatarColorValue);

  factory EmployeeFormState.fromEmployee(
    Employee employee, {
    List<Employee> managerOptions = const [],
  }) {
    return EmployeeFormState(
      mode: EmployeeFormMode.edit,
      companyId: employee.companyId,
      employeeId: employee.id,
      name: employee.name,
      mobile: employee.mobile,
      email: employee.email,
      department: employee.department,
      designation: employee.designation,
      role: employee.role,
      reportingManagerId: employee.reportingManagerId,
      employeeStatus: employee.status,
      avatarColorValue: employee.avatarColorValue,
      avatarIcon: employee.avatarIcon,
      createdAt: employee.createdAt,
      managerOptions: managerOptions,
    );
  }

  EmployeeFormState copyWith({
    EmployeeFormMode? mode,
    EmployeeFormStatus? status,
    String? companyId,
    String? employeeId,
    String? name,
    String? mobile,
    String? email,
    String? department,
    String? designation,
    EmployeeRole? role,
    String? reportingManagerId,
    EmployeeStatus? employeeStatus,
    int? avatarColorValue,
    String? avatarIcon,
    DateTime? createdAt,
    String? errorMessage,
    List<Employee>? managerOptions,
    bool clearError = false,
    bool clearManager = false,
  }) {
    return EmployeeFormState(
      mode: mode ?? this.mode,
      status: status ?? this.status,
      companyId: companyId ?? this.companyId,
      employeeId: employeeId ?? this.employeeId,
      name: name ?? this.name,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      department: department ?? this.department,
      designation: designation ?? this.designation,
      role: role ?? this.role,
      reportingManagerId: clearManager
          ? null
          : (reportingManagerId ?? this.reportingManagerId),
      employeeStatus: employeeStatus ?? this.employeeStatus,
      avatarColorValue: avatarColorValue ?? this.avatarColorValue,
      avatarIcon: avatarIcon ?? this.avatarIcon,
      createdAt: createdAt ?? this.createdAt,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      managerOptions: managerOptions ?? this.managerOptions,
    );
  }

  @override
  List<Object?> get props => [
    mode,
    status,
    companyId,
    employeeId,
    name,
    mobile,
    email,
    department,
    designation,
    role,
    reportingManagerId,
    employeeStatus,
    avatarColorValue,
    avatarIcon,
    createdAt,
    errorMessage,
    managerOptions,
  ];
}
