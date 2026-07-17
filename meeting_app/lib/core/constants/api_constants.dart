import '../config/env_config.dart';

/// API endpoint and header constants (backed by `.env`).
abstract final class ApiConstants {
  static String get baseUrl => EnvConfig.apiBaseUrl;

  static String get companyBaseUrl => EnvConfig.companyBaseUrl;

  static String get companySlug => EnvConfig.companySlug;

  static String get healthUrl => EnvConfig.apiHost;

  /// Relative to [companyBaseUrl] (e.g. `/api/v1/bangarProperties`).
  static const String loginPath = '/auth/login';
  static const String meetingsPath = '/meetings';
  static const String employeesPath = '/employees';

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  static const String contentType = 'application/json';
  static const String accept = 'application/json';
}
