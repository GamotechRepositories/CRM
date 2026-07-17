import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../domain/repositories/company_repository.dart';
import '../states/company_detail_state.dart';

class CompanyDetailController extends StateNotifier<CompanyDetailState> {
  CompanyDetailController(this._repository, this._companyId)
    : super(const CompanyDetailState());

  final CompanyRepository _repository;
  final String _companyId;

  Future<void> load() async {
    state = state.copyWith(
      status: CompanyDetailStatus.loading,
      clearError: true,
    );

    final result = await _repository.getCompanyById(_companyId);
    state = switch (result) {
      Success(:final data) => state.copyWith(
        status: CompanyDetailStatus.success,
        company: data,
      ),
      Error(:final failure) => state.copyWith(
        status: CompanyDetailStatus.error,
        errorMessage: failure.message,
      ),
    };
  }

  Future<bool> delete() async {
    state = state.copyWith(isDeleting: true, clearError: true);
    final result = await _repository.deleteCompany(_companyId);
    return switch (result) {
      Success() => true,
      Error(:final failure) => () {
        state = state.copyWith(
          isDeleting: false,
          errorMessage: failure.message,
        );
        return false;
      }(),
    };
  }
}
