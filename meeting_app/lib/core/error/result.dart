import 'failures.dart';

/// Functional result type for repository operations.
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Error<T>;

  T? get dataOrNull => switch (this) {
    Success<T>(:final data) => data,
    Error<T>() => null,
  };

  Failure? get failureOrNull => switch (this) {
    Success<T>() => null,
    Error<T>(:final failure) => failure,
  };

  Result<R> map<R>(R Function(T data) transform) => switch (this) {
    Success<T>(:final data) => Success(transform(data)),
    Error<T>(:final failure) => Error(failure),
  };

  Future<Result<R>> flatMap<R>(Future<Result<R>> Function(T data) transform) =>
      switch (this) {
        Success<T>(:final data) => transform(data),
        Error<T>(:final failure) => Future.value(Error(failure)),
      };
}

final class Success<T> extends Result<T> {
  const Success(this.data);

  final T data;
}

final class Error<T> extends Result<T> {
  const Error(this.failure);

  final Failure failure;
}
