import 'package:equatable/equatable.dart';

enum OtpStatus { initial, loading, success, error, resending }

class OtpState extends Equatable {
  const OtpState({
    required this.mobileNumber,
    required this.requestId,
    this.otp = '',
    this.status = OtpStatus.initial,
    this.errorMessage,
    this.resendSecondsRemaining = 30,
    this.showSuccess = false,
  });

  final String mobileNumber;
  final String requestId;
  final String otp;
  final OtpStatus status;
  final String? errorMessage;
  final int resendSecondsRemaining;
  final bool showSuccess;

  bool get isComplete => otp.length == 6;
  bool get isLoading =>
      status == OtpStatus.loading || status == OtpStatus.resending;
  bool get canResend => resendSecondsRemaining <= 0 && !isLoading;
  bool get canVerify => isComplete && !isLoading;

  OtpState copyWith({
    String? mobileNumber,
    String? requestId,
    String? otp,
    OtpStatus? status,
    String? errorMessage,
    int? resendSecondsRemaining,
    bool? showSuccess,
    bool clearError = false,
  }) {
    return OtpState(
      mobileNumber: mobileNumber ?? this.mobileNumber,
      requestId: requestId ?? this.requestId,
      otp: otp ?? this.otp,
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      resendSecondsRemaining:
          resendSecondsRemaining ?? this.resendSecondsRemaining,
      showSuccess: showSuccess ?? this.showSuccess,
    );
  }

  @override
  List<Object?> get props => [
    mobileNumber,
    requestId,
    otp,
    status,
    errorMessage,
    resendSecondsRemaining,
    showSuccess,
  ];
}
