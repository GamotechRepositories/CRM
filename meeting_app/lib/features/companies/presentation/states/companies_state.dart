import 'package:equatable/equatable.dart';

import '../../domain/entities/company.dart';

enum CompaniesStatus { initial, loading, success, error }

class CompaniesState extends Equatable {
  const CompaniesState({
    this.status = CompaniesStatus.initial,
    this.companies = const [],
    this.filtered = const [],
    this.searchQuery = '',
    this.errorMessage,
    this.isDeleting = false,
  });

  final CompaniesStatus status;
  final List<Company> companies;
  final List<Company> filtered;
  final String searchQuery;
  final String? errorMessage;
  final bool isDeleting;

  bool get isLoading => status == CompaniesStatus.loading;
  bool get isEmpty => filtered.isEmpty && !isLoading;
  int get activeCount =>
      companies.where((c) => c.status == CompanyStatus.active).length;

  CompaniesState copyWith({
    CompaniesStatus? status,
    List<Company>? companies,
    List<Company>? filtered,
    String? searchQuery,
    String? errorMessage,
    bool? isDeleting,
    bool clearError = false,
  }) {
    return CompaniesState(
      status: status ?? this.status,
      companies: companies ?? this.companies,
      filtered: filtered ?? this.filtered,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isDeleting: isDeleting ?? this.isDeleting,
    );
  }

  @override
  List<Object?> get props => [
    status,
    companies,
    filtered,
    searchQuery,
    errorMessage,
    isDeleting,
  ];
}
