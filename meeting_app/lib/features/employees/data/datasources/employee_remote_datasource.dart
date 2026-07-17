import 'package:dio/dio.dart';

import '../../../../core/config/env_config.dart';
import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/employee.dart';

class EmployeeRemoteDataSource {
  EmployeeRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<Employee>> getEmployees() async {
    try {
      final response = await _dio.get<List<dynamic>>('/employees');
      final data = response.data ?? const [];
      return data
          .map((e) => mapEmployee(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'EmployeeRemote.getAll');
      throw ErrorHandler.mapException(error);
    }
  }

  Future<Employee> getById(String id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/employees/$id');
      final data = response.data;
      if (data == null) throw const ServerException('Employee not found');
      return mapEmployee(data);
    } on DioException catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'EmployeeRemote.getById');
      throw ErrorHandler.mapException(error);
    }
  }

  static Employee mapEmployee(Map<String, dynamic> json) {
    final id = (json['_id'] ?? json['id'] ?? '').toString();
    final designation = json['designation'];
    final accessRole = designation is Map
        ? (designation['accessRole'] as String? ?? 'employee')
        : 'employee';
    final title = designation is Map
        ? (designation['title'] as String? ?? 'Employee')
        : 'Employee';
    final role = _mapRole(accessRole, title);
    final manager = json['reportingManager'];
    final managerId = manager is Map
        ? (manager['_id'] ?? manager['id'])?.toString()
        : manager?.toString();

    final mobile =
        (json['officialMobile'] as String?)?.replaceAll(RegExp(r'\D'), '') ??
        (json['personalMobile'] as String?)?.replaceAll(RegExp(r'\D'), '') ??
        '0000000000';

    final createdAt = _parseDate(json['createdAt']);
    final updatedAt = _parseDate(json['updatedAt'] ?? json['createdAt']);

    return Employee(
      id: id,
      companyId: EnvConfig.companySlug,
      name: json['name'] as String? ?? 'Employee',
      mobile: mobile.isEmpty ? '0000000000' : mobile,
      email: json['email'] as String? ?? '',
      department: json['department'] as String? ?? 'General',
      designation: title,
      role: role,
      status: (json['status'] as String?) == 'Inactive'
          ? EmployeeStatus.inactive
          : EmployeeStatus.active,
      reportingManagerId: managerId,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static EmployeeRole _mapRole(String accessRole, String title) {
    final lower = title.toLowerCase();
    if (accessRole == 'admin') return EmployeeRole.boss;
    if (lower.contains('personal assistant') ||
        lower.contains('executive assistant')) {
      return EmployeeRole.executiveAssistant;
    }
    if (accessRole == 'manager' || lower.contains('manager')) {
      return EmployeeRole.manager;
    }
    if (accessRole == 'technical_lead' ||
        lower.contains('lead') ||
        lower.contains('team lead')) {
      return EmployeeRole.teamLead;
    }
    return EmployeeRole.employee;
  }

  static DateTime _parseDate(dynamic value) {
    if (value is String && value.isNotEmpty) return DateTime.parse(value);
    return DateTime.now();
  }
}
