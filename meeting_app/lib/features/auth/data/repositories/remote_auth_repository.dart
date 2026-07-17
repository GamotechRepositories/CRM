import '../../../../core/error/error_handler.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/auth_session_model.dart';

/// Authenticates with central admin (create-team) credentials.
class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository({
    required AuthRemoteDataSource remote,
    required AuthLocalDataSource local,
  }) : _remote = remote,
       _local = local;

  final AuthRemoteDataSource _remote;
  final AuthLocalDataSource _local;

  @override
  Future<Result<AuthSession?>> getSession() async {
    try {
      final model = await _local.readSession();
      if (model == null) return const Success(null);
      final session = model.toEntity();
      if (!session.isValid) {
        await _local.clearSession();
        return const Success(null);
      }
      return Success(session);
    } catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'RemoteAuth.getSession');
      return Error(ErrorHandler.mapException(error));
    }
  }

  @override
  Future<Result<bool>> isLoggedIn() async {
    final sessionResult = await getSession();
    return switch (sessionResult) {
      Success(:final data) => Success(data != null && data.isValid),
      Error(:final failure) => Error(failure),
    };
  }

  @override
  Future<Result<String>> sendOtp(String mobileNumber) async {
    return const Error(
      ValidationFailure('Sign in with the email and password from Create Team'),
    );
  }

  @override
  Future<Result<AuthSession>> verifyOtp({
    required String mobileNumber,
    required String otp,
    required String requestId,
  }) async {
    return const Error(
      ValidationFailure('Sign in with the email and password from Create Team'),
    );
  }

  @override
  Future<Result<void>> resendOtp({
    required String mobileNumber,
    required String requestId,
  }) async {
    return const Error(ValidationFailure('OTP is not used'));
  }

  @override
  Future<Result<AuthSession>> loginWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _remote.login(email: email, password: password);
      final session = AuthSessionModel(
        user: AuthUserModel.fromEntity(result.user),
        token: result.token,
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );
      await _local.saveSession(session);
      return Success(session.toEntity());
    } on Failure catch (failure) {
      return Error(failure);
    } catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'RemoteAuth.login');
      return Error(ErrorHandler.mapException(error));
    }
  }

  @override
  Future<Result<void>> logout() async {
    try {
      await _local.clearSession();
      return const Success(null);
    } catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'RemoteAuth.logout');
      return Error(ErrorHandler.mapException(error));
    }
  }
}
