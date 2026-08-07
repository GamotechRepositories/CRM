import 'package:flutter_dotenv/flutter_dotenv.dart';

/// App-wide env helpers (loaded from `.env`).
class AppEnv {
  static String get appName => dotenv.env['APP_NAME']?.trim().isNotEmpty == true
      ? dotenv.env['APP_NAME']!.trim()
      : 'MultiCRM';

  static String get apiHost =>
      dotenv.env['API_HOST']?.trim() ?? 'http://localhost:5011';

  static String get socketUrl =>
      dotenv.env['SOCKET_URL']?.trim() ?? apiHost;

  static String require(String key) {
    final value = dotenv.env[key]?.trim();
    if (value == null || value.isEmpty) {
      throw StateError('Missing .env key: $key');
    }
    return value;
  }
}
