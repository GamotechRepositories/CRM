import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_client.dart';
import '../../core/storage/hive_service.dart';

/// Global dependency overrides for the application.
List<Override> createAppOverrides(HiveService hiveService) {
  return [hiveServiceProvider.overrideWithValue(hiveService)];
}

/// Convenience accessors for core providers.
abstract final class AppProviders {
  static final dio = dioProvider;
  static final hive = hiveServiceProvider;
}
