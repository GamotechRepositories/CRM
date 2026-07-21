import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/config/env_config.dart';
import 'core/constants/app_constants.dart';
import 'core/constants/storage_keys.dart';
import 'core/storage/hive_service.dart';
import 'core/utils/logger.dart';
import 'services/notification_service.dart';

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

  NotificationService.instance.bindAuthTokenProvider(
    () => hiveService.get<String>(StorageKeys.authToken),
  );

  // FCM setup must not block the first frame — warm up in background.
  unawaited(_warmUpNotifications());

  AppLogger.info(
    'CRM backend ready · ${EnvConfig.companyBaseUrl}',
  );

  return hiveService;
}

Future<void> _warmUpNotifications() async {
  try {
    await NotificationService.instance
        .initialize()
        .timeout(AppConstants.networkTimeout);
    await NotificationService.instance
        .requestPermission()
        .timeout(const Duration(seconds: 60));
  } catch (error) {
    AppLogger.error(
      'Push notifications unavailable — app will continue',
      tag: 'FCM',
      error: error,
    );
  }
}
