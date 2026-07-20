import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/repositories/auth_repository.dart';
import '../states/login_state.dart';

class LoginController extends StateNotifier<LoginState> {
  LoginController(this._repository) : super(const LoginState());

  final AuthRepository _repository;

  void onEmailChanged(String value) {
    state = state.copyWith(
      email: value,
      status: LoginStatus.initial,
      clearError: true,
    );
  }

  void onPasswordChanged(String value) {
    state = state.copyWith(
      password: value,
      status: LoginStatus.initial,
      clearError: true,
    );
  }

  /// Legacy OTP entry — kept for compatibility.
  void onMobileChanged(String value) {
    state = state.copyWith(
      mobileNumber: value,
      status: LoginStatus.initial,
      clearError: true,
    );
  }

  Future<bool> continueWithMobile() async {
    final validationError = Validators.mobile(state.mobileNumber);
    if (validationError != null) {
      state = state.copyWith(
        status: LoginStatus.error,
        errorMessage: validationError,
      );
      return false;
    }

    state = state.copyWith(status: LoginStatus.loading, clearError: true);

    final mobile = Validators.normalizeMobile(state.mobileNumber);
    final result = await _repository.sendOtp(mobile);

    return switch (result) {
      Success(:final data) => () {
        state = state.copyWith(
          mobileNumber: mobile,
          status: LoginStatus.success,
          requestId: data,
        );
        return true;
      }(),
      Error(:final failure) => () {
        state = state.copyWith(
          status: LoginStatus.error,
          errorMessage: failure.message,
        );
        return false;
      }(),
    };
  }

  String _loginErrorMessage(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid email') || lower.contains('invalid password')) {
      return 'Invalid email or password.\n'
          'Use Create Team login (Admin → Create Team) or your company CRM employee email/password.';
    }
    if (lower.contains('not set up for login')) {
      return '$message\nAsk admin to set your CRM password first.';
    }
    return message;
  }

  Future<bool> loginWithPassword() async {
    final emailError = Validators.email(state.email);
    if (emailError != null) {
      state = state.copyWith(
        status: LoginStatus.error,
        errorMessage: emailError,
      );
      return false;
    }
    if (state.password.trim().isEmpty) {
      state = state.copyWith(
        status: LoginStatus.error,
        errorMessage: 'Password is required',
      );
      return false;
    }

    state = state.copyWith(status: LoginStatus.loading, clearError: true);
    final result = await _repository.loginWithPassword(
      email: state.email.trim(),
      password: state.password,
    );

    return switch (result) {
      Success() => () {
        state = state.copyWith(status: LoginStatus.success);
        return true;
      }(),
      Error(:final failure) => () {
        state = state.copyWith(
          status: LoginStatus.error,
          errorMessage: _loginErrorMessage(failure.message),
        );
        return false;
      }(),
    };
  }
}
