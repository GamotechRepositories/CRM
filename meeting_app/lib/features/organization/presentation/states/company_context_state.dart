import 'package:equatable/equatable.dart';

import '../../../auth/domain/entities/auth_user.dart';
import '../../../companies/domain/entities/company.dart';
import '../../domain/entities/organization_access.dart';

enum CompanyContextStatus { initial, loading, ready, error }

class CompanyContextState extends Equatable {
  const CompanyContextState({
    this.status = CompanyContextStatus.initial,
    this.user,
    this.companies = const [],
    this.activeCompanyId,
    this.errorMessage,
    this.isSwitching = false,
  });

  final CompanyContextStatus status;
  final AuthUser? user;
  final List<Company> companies;
  final String? activeCompanyId;
  final String? errorMessage;
  final bool isSwitching;

  bool get isReady => status == CompanyContextStatus.ready;

  Company? get activeCompany {
    if (companies.isEmpty) return null;
    return companies.cast<Company?>().firstWhere(
      (c) => c!.id == activeCompanyId,
      orElse: () => companies.first,
    );
  }

  OrganizationAccess? get access {
    final currentUser = user;
    if (currentUser == null) return null;
    return OrganizationAccess(
      user: currentUser,
      accessibleCompanies: companies,
      activeCompanyId: activeCompanyId,
    );
  }

  CompanyContextState copyWith({
    CompanyContextStatus? status,
    AuthUser? user,
    List<Company>? companies,
    String? activeCompanyId,
    String? errorMessage,
    bool? isSwitching,
    bool clearError = false,
  }) {
    return CompanyContextState(
      status: status ?? this.status,
      user: user ?? this.user,
      companies: companies ?? this.companies,
      activeCompanyId: activeCompanyId ?? this.activeCompanyId,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isSwitching: isSwitching ?? this.isSwitching,
    );
  }

  @override
  List<Object?> get props => [
    status,
    user,
    companies,
    activeCompanyId,
    errorMessage,
    isSwitching,
  ];
}
