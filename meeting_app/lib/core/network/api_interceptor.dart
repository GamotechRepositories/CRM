import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../utils/logger.dart';

class ApiInterceptor extends Interceptor {
  ApiInterceptor({this.authTokenProvider});

  final String? Function()? authTokenProvider;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = authTokenProvider?.call();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    AppLogger.debug('→ ${options.method} ${options.uri}', tag: 'Dio');
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    AppLogger.debug(
      '← ${response.statusCode} ${response.requestOptions.uri}',
      tag: 'Dio',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      AppLogger.error(
        '✕ ${err.requestOptions.method} ${err.requestOptions.uri}: ${err.message}',
        tag: 'Dio',
      );
    }
    handler.next(err);
  }
}
