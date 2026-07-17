import 'package:equatable/equatable.dart';

enum LoginStatus { initial, loading, success, error }

class LoginState extends Equatable {
  const LoginState({
    this.email = '',
    this.password = '',
    this.mobileNumber = '',
    this.status = LoginStatus.initial,
    this.errorMessage,
    this.requestId,
  });

  final String email;
  final String password;
  final String mobileNumber;
  final LoginStatus status;
  final String? errorMessage;
  final String? requestId;

  bool get isValidEmailPassword =>
      email.trim().isNotEmpty && password.trim().isNotEmpty;
  bool get isValid =>
      mobileNumber.replaceAll(RegExp(r'\D'), '').length >= 10;
  bool get isLoading => status == LoginStatus.loading;
  bool get canSubmit => isValidEmailPassword && !isLoading;

  LoginState copyWith({
    String? email,
    String? password,
    String? mobileNumber,
    LoginStatus? status,
    String? errorMessage,
    String? requestId,
    bool clearError = false,
  }) {
    return LoginState(
      email: email ?? this.email,
      password: password ?? this.password,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      requestId: requestId ?? this.requestId,
    );
  }

  @override
  List<Object?> get props => [
        email,
        password,
        mobileNumber,
        status,
        errorMessage,
        requestId,
      ];
}
