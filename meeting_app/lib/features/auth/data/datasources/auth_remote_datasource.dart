import 'package:dio/dio.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../../employees/domain/entities/employee.dart';
import '../../domain/entities/auth_user.dart';

/// HTTP auth against central admin (`POST /auth/login`).
/// Same accounts created at http://localhost:5177/create-team
class AuthRemoteDataSource {
  AuthRemoteDataSource(this._dio);

  final Dio _dio;

  Future<RemoteLoginResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email.trim().toLowerCase(), 'password': password},
      );
      final data = response.data;
      if (data == null) {
        throw const ServerException('Empty login response');
      }
      final token = data['token'] as String?;
      final userJson = data['user'];
      if (token == null || token.isEmpty || userJson is! Map) {
        throw const ServerException('Login response missing token or user');
      }
      return RemoteLoginResult(
        token: token,
        user: mapCentralAdminUser(Map<String, dynamic>.from(userJson)),
      );
    } on DioException catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'AuthRemote.login');
      throw ErrorHandler.mapException(error);
    }
  }

  /// Maps create-team / CEO users → Flutter auth + RBAC.
  /// Boss = CEO (isRoot). Everyone else = team member who creates meetings.
  static AuthUser mapCentralAdminUser(Map<String, dynamic> json) {
    final id = (json['_id'] ?? json['id'] ?? '').toString();
    final role = (json['role'] as String? ?? '').trim();
    final isRoot = json['isRoot'] == true || role.toUpperCase() == 'CEO';
    final phone = (json['phone'] as String?)?.replaceAll(RegExp(r'\D'), '') ?? '';

    final rawTenants = json['tenants'];
    final tenants = rawTenants is List
        ? rawTenants.map((e) => e.toString()).toList()
        : <String>[];

    return AuthUser(
      id: id,
      mobileNumber: phone.isEmpty ? '0000000000' : phone,
      displayName: json['name'] as String? ?? 'User',
      email: (json['email'] as String?)?.trim().toLowerCase(),
      appRole: isRoot ? AppRole.boss : AppRole.member,
      employeeId: id,
      employeeRole:
          isRoot ? EmployeeRole.boss : EmployeeRole.executiveAssistant,
      homeCompanyId: 'central',
      roleLabel: isRoot ? 'Boss' : (role.isEmpty ? 'Team' : role),
      tenants: tenants,
    );
  }
}

class RemoteLoginResult {
  const RemoteLoginResult({required this.token, required this.user});

  final String token;
  final AuthUser user;
}
