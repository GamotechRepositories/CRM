import '../../../../core/error/result.dart';
import '../entities/auth_session.dart';

/// Contract for authentication operations.
abstract class AuthRepository {
  Future<Result<AuthSession?>> getSession();

  Future<Result<bool>> isLoggedIn();

  /// CRM email/password login (primary when using live backend).
  Future<Result<AuthSession>> loginWithPassword({
    required String email,
    required String password,
  });

  /// Sends OTP to [mobileNumber]. Returns a request/session id for verification.
  Future<Result<String>> sendOtp(String mobileNumber);

  Future<Result<AuthSession>> verifyOtp({
    required String mobileNumber,
    required String otp,
    required String requestId,
  });

  Future<Result<void>> resendOtp({
    required String mobileNumber,
    required String requestId,
  });

  Future<Result<void>> logout();
}
