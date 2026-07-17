import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env_config.dart';
import '../constants/api_constants.dart';
import '../constants/storage_keys.dart';
import '../storage/hive_service.dart';
import 'api_interceptor.dart';

final dioProvider = Provider<Dio>((ref) {
  final hive = ref.watch(hiveServiceProvider);
  return DioClient.create(
    authTokenProvider: () => hive.get<String>(StorageKeys.authToken),
  );
});

abstract final class DioClient {
  static Dio create({String? Function()? authTokenProvider}) {
    final dio = Dio(
      BaseOptions(
        // Company-scoped root so feature calls can use relative paths
        // e.g. dio.get('/auth/login') → /api/v1/{company}/auth/login
        baseUrl: EnvConfig.companyBaseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        sendTimeout: ApiConstants.sendTimeout,
        headers: {
          'Content-Type': ApiConstants.contentType,
          'Accept': ApiConstants.accept,
        },
      ),
    );

    dio.interceptors.addAll([
      ApiInterceptor(authTokenProvider: authTokenProvider),
      if (EnvConfig.isDevelopment)
        LogInterceptor(requestBody: true, responseBody: true),
    ]);

    return dio;
  }
}
