import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env_config.dart';
import '../error/error_handler.dart';
import '../error/result.dart';
import 'dio_client.dart';

final apiHealthProvider = FutureProvider.autoDispose<Result<String>>((
  ref,
) async {
  final dio = ref.watch(dioProvider);
  return ApiHealthService(dio).check();
});

class ApiHealthService {
  ApiHealthService(this._dio);

  final Dio _dio;

  /// Hits CRM root (`API_HOST`) which returns "Welcome to the CRM API".
  Future<Result<String>> check() async {
    try {
      // Absolute URL bypasses Dio baseUrl (/api/v1/{company}).
      final response = await _dio.get<dynamic>(
        EnvConfig.apiHost,
        options: Options(responseType: ResponseType.plain),
      );
      final body = response.data?.toString() ?? 'OK';
      return Success(body);
    } catch (error, stackTrace) {
      ErrorHandler.logError(error, stackTrace, context: 'ApiHealth');
      return Error(ErrorHandler.mapException(error));
    }
  }
}
