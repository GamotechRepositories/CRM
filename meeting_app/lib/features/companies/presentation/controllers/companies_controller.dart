import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../organization/domain/repositories/organization_repository.dart';
import '../../domain/entities/company.dart';
import '../../domain/repositories/company_repository.dart';
import '../states/companies_state.dart';

class CompaniesController extends StateNotifier<CompaniesState> {
  CompaniesController({
    required CompanyRepository companyRepository,
    required OrganizationRepository organizationRepository,
    required AuthUser? user,
  }) : _companies = companyRepository,
       _organization = organizationRepository,
       _user = user,
       super(const CompaniesState());

  final CompanyRepository _companies;
  final OrganizationRepository _organization;
  final AuthUser? _user;

  Future<void> load() async {
    state = state.copyWith(status: CompaniesStatus.loading, clearError: true);

    final user = _user;
    if (user == null) {
      state = state.copyWith(
        status: CompaniesStatus.success,
        companies: const [],
        filtered: const [],
      );
      return;
    }

    final result = await _organization.getAccessibleCompanies(user);
    state = switch (result) {
      Success(:final data) => state.copyWith(
        status: CompaniesStatus.success,
        companies: data,
        filtered: _applyQuery(data, state.searchQuery),
      ),
      Error(:final failure) => state.copyWith(
        status: CompaniesStatus.error,
        errorMessage: failure.message,
      ),
    };
  }

  Future<void> search(String query) async {
    state = state.copyWith(searchQuery: query);
    state = state.copyWith(filtered: _applyQuery(state.companies, query));
  }

  Future<bool> deleteCompany(String id) async {
    if (_user == null) {
      state = state.copyWith(errorMessage: 'Not signed in');
      return false;
    }

    // Deletion is gated by UI via AppPermission.deleteCompany.
    // Repository still requires owner-scoped company records.

    state = state.copyWith(isDeleting: true, clearError: true);
    final result = await _companies.deleteCompany(id);
    switch (result) {
      case Success():
        await load();
        state = state.copyWith(isDeleting: false);
        return true;
      case Error(:final failure):
        state = state.copyWith(
          isDeleting: false,
          errorMessage: failure.message,
        );
        return false;
    }
  }

  List<Company> _applyQuery(List<Company> source, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return source;
    return source
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.industry.toLowerCase().contains(q) ||
              c.email.toLowerCase().contains(q),
        )
        .toList();
  }
}
