import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../companies/domain/repositories/company_repository.dart';
import '../../domain/entities/employee.dart';
import '../../domain/repositories/employee_repository.dart';
import '../states/employee_detail_state.dart';

class EmployeeDetailController extends StateNotifier<EmployeeDetailState> {
  EmployeeDetailController({
    required EmployeeRepository employeeRepository,
    required CompanyRepository companyRepository,
    required String employeeId,
  }) : _employees = employeeRepository,
       _companies = companyRepository,
       _employeeId = employeeId,
       super(const EmployeeDetailState());

  final EmployeeRepository _employees;
  final CompanyRepository _companies;
  final String _employeeId;

  Future<void> load() async {
    state = state.copyWith(
      status: EmployeeDetailStatus.loading,
      clearError: true,
      clearManager: true,
    );

    final result = await _employees.getById(_employeeId);
    switch (result) {
      case Error(:final failure):
        state = state.copyWith(
          status: EmployeeDetailStatus.error,
          errorMessage: failure.message,
        );
        return;
      case Success(:final data):
        final companyResult = await _companies.getCompanyById(data.companyId);
        final companyName = switch (companyResult) {
          Success(:final data) => data.name,
          Error() => null,
        };

        Employee? manager;
        if (data.reportingManagerId != null) {
          final managerResult = await _employees.getById(
            data.reportingManagerId!,
          );
          manager = switch (managerResult) {
            Success(:final data) => data,
            Error() => null,
          };
        }

        final peers = await _employees.getByCompany(data.companyId);
        final reports = switch (peers) {
          Success(:final data) =>
            data.where((e) => e.reportingManagerId == _employeeId).toList(),
          Error() => <Employee>[],
        };

        state = state.copyWith(
          status: EmployeeDetailStatus.success,
          employee: data,
          manager: manager,
          clearManager: manager == null,
          directReports: reports,
          companyName: companyName,
        );
    }
  }

  Future<bool> delete() async {
    state = state.copyWith(isDeleting: true, clearError: true);
    final result = await _employees.delete(_employeeId);
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
