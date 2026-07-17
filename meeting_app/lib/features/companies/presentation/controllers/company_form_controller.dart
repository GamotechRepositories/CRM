import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/entities/company.dart';
import '../../domain/repositories/company_repository.dart';
import '../states/company_form_state.dart';

class CompanyFormController extends StateNotifier<CompanyFormState> {
  CompanyFormController({
    required CompanyRepository repository,
    required String ownerId,
    Company? existing,
  }) : _repository = repository,
       _ownerId = ownerId,
       super(
         existing != null
             ? CompanyFormState.fromCompany(existing)
             : const CompanyFormState(mode: CompanyFormMode.create),
       );

  final CompanyRepository _repository;
  final String _ownerId;

  void updateName(String value) =>
      state = state.copyWith(name: value, clearError: true);

  void updateIndustry(String value) =>
      state = state.copyWith(industry: value, clearError: true);

  void updateAddress(String value) =>
      state = state.copyWith(address: value, clearError: true);

  void updateWebsite(String value) =>
      state = state.copyWith(website: value, clearError: true);

  void updateEmail(String value) =>
      state = state.copyWith(email: value, clearError: true);

  void updatePhone(String value) =>
      state = state.copyWith(phone: value, clearError: true);

  void updateEmployeeCount(int value) =>
      state = state.copyWith(employeeCount: value, clearError: true);

  void updateColor(int value) =>
      state = state.copyWith(colorValue: value, clearError: true);

  void updateStatus(CompanyStatus value) =>
      state = state.copyWith(companyStatus: value, clearError: true);

  void updateLogoIcon(String value) =>
      state = state.copyWith(logoIcon: value, clearError: true);

  String? validate() {
    if (state.name.trim().isEmpty) return 'Company name is required';
    if (state.industry.trim().isEmpty) return 'Industry is required';
    if (state.address.trim().isEmpty) return 'Address is required';
    if (state.employeeCount < 1) return 'Employees must be at least 1';
    if (state.email.trim().isNotEmpty) {
      final emailError = Validators.email(state.email);
      if (emailError != null) return emailError;
    }
    if (state.phone.trim().isNotEmpty) {
      final digits = state.phone.replaceAll(RegExp(r'\D'), '');
      if (digits.length < 8) return 'Enter a valid phone number';
    }
    return null;
  }

  Future<Company?> submit() async {
    final validationError = validate();
    if (validationError != null) {
      state = state.copyWith(
        status: CompanyFormStatus.error,
        errorMessage: validationError,
      );
      return null;
    }

    state = state.copyWith(status: CompanyFormStatus.loading, clearError: true);
    final now = DateTime.now();

    final company = Company(
      id: state.companyId ?? 'co_${now.millisecondsSinceEpoch}',
      ownerId: _ownerId,
      name: state.name.trim(),
      industry: state.industry.trim(),
      address: state.address.trim(),
      website: state.website.trim(),
      email: state.email.trim(),
      phone: state.phone.trim(),
      employeeCount: state.employeeCount,
      colorValue: state.colorValue,
      status: state.companyStatus,
      logoIcon: state.logoIcon,
      createdAt: state.createdAt ?? now,
      updatedAt: now,
    );

    final result = state.mode == CompanyFormMode.create
        ? await _repository.createCompany(company)
        : await _repository.updateCompany(company);

    return switch (result) {
      Success(:final data) => () {
        state = state.copyWith(status: CompanyFormStatus.success);
        return data;
      }(),
      Error(:final failure) => () {
        state = state.copyWith(
          status: CompanyFormStatus.error,
          errorMessage: failure.message,
        );
        return null;
      }(),
    };
  }
}
