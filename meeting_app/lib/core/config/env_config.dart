import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Runtime environment loaded from `.env` via flutter_dotenv.
abstract final class EnvConfig {
  static String get apiBaseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://192.168.1.36:5011/api/v1';

  static String get apiHost =>
      dotenv.env['API_HOST'] ?? 'http://192.168.1.36:5011';

  static String get appEnv => dotenv.env['APP_ENV'] ?? 'development';

  static bool get isDevelopment => appEnv == 'development';

  /// Central admin API used by create-team + meeting app.
  /// Example: http://host:5011/api/v1/admin
  static String get adminBaseUrl => '$apiBaseUrl/admin';

  /// @deprecated Kept for older call sites; meeting app uses [adminBaseUrl].
  static String get companySlug => 'central';

  static String get companyBaseUrl => adminBaseUrl;
}
