import 'package:equatable/equatable.dart';

/// User-facing failure types returned from repositories.
sealed class Failure extends Equatable {
  const Failure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  List<Object?> get props => [message, code];
}

final class NetworkFailure extends Failure {
  const NetworkFailure([
    String message = 'No internet connection',
    String? code,
  ]) : super(message, code: code);
}

final class ServerFailure extends Failure {
  const ServerFailure([String message = 'Something went wrong', String? code])
    : super(message, code: code);
}

final class CacheFailure extends Failure {
  const CacheFailure([String message = 'Local storage error', String? code])
    : super(message, code: code);
}

final class ValidationFailure extends Failure {
  const ValidationFailure(String message, {String? code})
    : super(message, code: code);
}

final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([String message = 'Session expired', String? code])
    : super(message, code: code);
}

final class UnknownFailure extends Failure {
  const UnknownFailure([
    String message = 'An unexpected error occurred',
    String? code,
  ]) : super(message, code: code);
}
