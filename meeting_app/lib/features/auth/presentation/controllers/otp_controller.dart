import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/repositories/auth_repository.dart';
import '../states/otp_state.dart';

class OtpController extends StateNotifier<OtpState> {
  OtpController({
    required AuthRepository repository,
    required String mobileNumber,
    required String requestId,
  }) : _repository = repository,
       super(
         OtpState(
           mobileNumber: Validators.normalizeMobile(mobileNumber),
           requestId: requestId,
         ),
       ) {
    _startResendTimer();
  }

  final AuthRepository _repository;
  Timer? _timer;
  bool _isVerifying = false;

  void onOtpChanged(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    final otp = digits.length > 6 ? digits.substring(0, 6) : digits;
    state = state.copyWith(
      otp: otp,
      status: OtpStatus.initial,
      clearError: true,
      showSuccess: false,
    );

    if (otp.length == 6) {
      verifyOtp();
    }
  }

  Future<bool> verifyOtp() async {
    if (_isVerifying || !state.isComplete) return false;
    _isVerifying = true;

    final validationError = Validators.otp(state.otp);
    if (validationError != null) {
      state = state.copyWith(
        status: OtpStatus.error,
        errorMessage: validationError,
      );
      _isVerifying = false;
      return false;
    }

    state = state.copyWith(status: OtpStatus.loading, clearError: true);

    final result = await _repository.verifyOtp(
      mobileNumber: state.mobileNumber,
      otp: state.otp,
      requestId: state.requestId,
    );

    final success = switch (result) {
      Success() => true,
      Error(:final failure) => () {
        state = state.copyWith(
          status: OtpStatus.error,
          errorMessage: failure.message,
          otp: '',
        );
        return false;
      }(),
    };

    if (success) {
      state = state.copyWith(status: OtpStatus.success, showSuccess: true);
    }

    _isVerifying = false;
    return success;
  }

  Future<bool> resendOtp() async {
    if (!state.canResend) return false;

    state = state.copyWith(status: OtpStatus.resending, clearError: true);

    final result = await _repository.resendOtp(
      mobileNumber: state.mobileNumber,
      requestId: state.requestId,
    );

    return switch (result) {
      Success() => () {
        state = state.copyWith(
          status: OtpStatus.initial,
          otp: '',
          resendSecondsRemaining: 30,
        );
        _startResendTimer();
        return true;
      }(),
      Error(:final failure) => () {
        state = state.copyWith(
          status: OtpStatus.error,
          errorMessage: failure.message,
        );
        return false;
      }(),
    };
  }

  void _startResendTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (state.resendSecondsRemaining <= 1) {
        timer.cancel();
        state = state.copyWith(resendSecondsRemaining: 0);
      } else {
        state = state.copyWith(
          resendSecondsRemaining: state.resendSecondsRemaining - 1,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
