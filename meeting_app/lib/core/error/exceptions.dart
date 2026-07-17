/// Domain-level exceptions thrown by data sources.
sealed class AppException implements Exception {
  const AppException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => 'AppException($code): $message';
}

final class NetworkException extends AppException {
  const NetworkException([String message = 'Network error', String? code])
    : super(message, code: code);
}

final class ServerException extends AppException {
  const ServerException([
    String message = 'Server error',
    String? code,
    this.statusCode,
  ]) : super(message, code: code);

  final int? statusCode;
}

final class CacheException extends AppException {
  const CacheException([String message = 'Cache error', String? code])
    : super(message, code: code);
}

final class ValidationException extends AppException {
  const ValidationException([String message = 'Validation error', String? code])
    : super(message, code: code);
}

final class UnauthorizedException extends AppException {
  const UnauthorizedException([String message = 'Unauthorized', String? code])
    : super(message, code: code);
}
