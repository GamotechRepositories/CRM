import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'exceptions.dart';
import 'failures.dart';

/// Maps exceptions and Dio errors to domain failures.
abstract final class ErrorHandler {
  static Failure mapException(Object error) {
    return switch (error) {
      NetworkException(:final message, :final code) => NetworkFailure(
        message,
        code,
      ),
      ServerException(:final message, :final code) => ServerFailure(
        message,
        code,
      ),
      CacheException(:final message, :final code) => CacheFailure(
        message,
        code,
      ),
      ValidationException(:final message, :final code) => ValidationFailure(
        message,
        code: code,
      ),
      UnauthorizedException(:final message, :final code) => UnauthorizedFailure(
        message,
        code,
      ),
      DioException dioError => _mapDioError(dioError),
      _ => UnknownFailure(error.toString()),
    };
  }

  static Failure _mapDioError(DioException error) {
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return const NetworkFailure('Unable to reach the server');
    }

    final statusCode = error.response?.statusCode;
    final message =
        _extractMessage(error.response?.data) ??
        error.message ??
        'Request failed';

    if (statusCode == 401) {
      return UnauthorizedFailure(message);
    }

    if (statusCode != null && statusCode >= 500) {
      return ServerFailure(message, statusCode.toString());
    }

    return ServerFailure(message, statusCode?.toString());
  }

  static String? _extractMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data['message'] as String? ?? data['error'] as String?;
    }
    return null;
  }

  static void logError(Object error, StackTrace stackTrace, {String? context}) {
    if (kDebugMode) {
      debugPrint(
        '[ErrorHandler${context != null ? ' · $context' : ''}] $error',
      );
      debugPrint(stackTrace.toString());
    }
  }
}
