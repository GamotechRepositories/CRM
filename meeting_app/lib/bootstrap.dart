import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/config/env_config.dart';
import 'core/storage/hive_service.dart';
import 'core/utils/logger.dart';

/// Initializes app services before runApp.
Future<HiveService> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.info('Bootstrapping application…');

  await dotenv.load(fileName: '.env');
  AppLogger.info(
    'Env loaded · ${EnvConfig.appEnv} · ${EnvConfig.companyBaseUrl}',
  );

  final hiveService = await HiveService.init();
  AppLogger.info('Hive initialized');
  AppLogger.info(
    'CRM backend ready · ${EnvConfig.companyBaseUrl}',
  );

  return hiveService;
}
