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
    final extracted = _extractMessage(error.response?.data);
    final rawMessage = error.message ?? '';

    // Dio's default validateStatus text is useless in the UI.
    final isDioStatusBlurb = rawMessage.contains('validateStatus') ||
        rawMessage.contains('status code of');

    final message = extracted ??
        (isDioStatusBlurb
            ? _friendlyStatusMessage(statusCode)
            : (rawMessage.isNotEmpty
                ? rawMessage
                : _friendlyStatusMessage(statusCode)));

    if (statusCode == 401) {
      return UnauthorizedFailure(message);
    }

    if (statusCode == 404) {
      return ServerFailure(
        extracted ??
            'Meeting API not found on the server. Ask admin to redeploy the latest backend.',
        '404',
      );
    }

    if (statusCode != null && statusCode >= 500) {
      return ServerFailure(message, statusCode.toString());
    }

    return ServerFailure(message, statusCode?.toString());
  }

  static String _friendlyStatusMessage(int? statusCode) {
    return switch (statusCode) {
      400 => 'Invalid request. Check the form and try again.',
      403 => 'You do not have permission for this action.',
      404 => 'API endpoint not found on the server.',
      409 => 'This conflicts with an existing record.',
      422 => 'Some fields are invalid.',
      500 || 502 || 503 => 'Server error. Please try again in a moment.',
      _ => 'Request failed${statusCode != null ? ' ($statusCode)' : ''}.',
    };
  }

  static String? _extractMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data['message'] as String? ?? data['error'] as String?;
    }
    if (data is String) {
      final trimmed = data.trim();
      // Express default HTML body: <pre>Cannot POST /path</pre>
      final pre = RegExp(
        r'<pre>([^<]+)</pre>',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (pre != null) return pre.group(1)?.trim();
      if (trimmed.isNotEmpty && !trimmed.startsWith('<')) return trimmed;
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
