import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/hive_service.dart';
import '../../../../core/utils/validators.dart';
import '../../data/datasources/auth_local_datasource.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/remote_auth_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import '../controllers/auth_session_controller.dart';
import '../controllers/login_controller.dart';
import '../controllers/otp_controller.dart';
import '../states/auth_session_state.dart';
import '../states/login_state.dart';
import '../states/otp_state.dart';

final authLocalDataSourceProvider = Provider<AuthLocalDataSource>((ref) {
  return AuthLocalDataSource(ref.watch(hiveServiceProvider));
});

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource(ref.watch(dioProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return RemoteAuthRepository(
    remote: ref.watch(authRemoteDataSourceProvider),
    local: ref.watch(authLocalDataSourceProvider),
  );
});

/// Legacy OTP hint (OTP login is unused with Create Team auth).
const kDemoOtp = '123456';

final authSessionProvider =
    StateNotifierProvider<AuthSessionController, AuthSessionState>((ref) {
      return AuthSessionController(ref.watch(authRepositoryProvider));
    });

final loginControllerProvider =
    StateNotifierProvider.autoDispose<LoginController, LoginState>((ref) {
      return LoginController(ref.watch(authRepositoryProvider));
    });

final otpControllerProvider = StateNotifierProvider.autoDispose
    .family<OtpController, OtpState, OtpArgs>((ref, args) {
      return OtpController(
        repository: ref.watch(authRepositoryProvider),
        mobileNumber: args.mobileNumber,
        requestId: args.requestId,
      );
    });

class OtpArgs {
  const OtpArgs({required this.mobileNumber, required this.requestId});

  final String mobileNumber;
  final String requestId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OtpArgs &&
          runtimeType == other.runtimeType &&
          mobileNumber == other.mobileNumber &&
          requestId == other.requestId;

  @override
  int get hashCode => Object.hash(mobileNumber, requestId);
}

class OtpRouteArgs {
  const OtpRouteArgs({required this.mobileNumber, required this.requestId});

  final String mobileNumber;
  final String requestId;

  String get normalizedMobile => Validators.normalizeMobile(mobileNumber);
}
