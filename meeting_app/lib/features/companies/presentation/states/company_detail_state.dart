import 'package:equatable/equatable.dart';

import '../../domain/entities/company.dart';

enum CompanyDetailStatus { initial, loading, success, error }

class CompanyDetailState extends Equatable {
  const CompanyDetailState({
    this.status = CompanyDetailStatus.initial,
    this.company,
    this.errorMessage,
    this.isDeleting = false,
  });

  final CompanyDetailStatus status;
  final Company? company;
  final String? errorMessage;
  final bool isDeleting;

  bool get isLoading => status == CompanyDetailStatus.loading;

  CompanyDetailState copyWith({
    CompanyDetailStatus? status,
    Company? company,
    String? errorMessage,
    bool? isDeleting,
    bool clearError = false,
  }) {
    return CompanyDetailState(
      status: status ?? this.status,
      company: company ?? this.company,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isDeleting: isDeleting ?? this.isDeleting,
    );
  }

  @override
  List<Object?> get props => [status, company, errorMessage, isDeleting];
}
