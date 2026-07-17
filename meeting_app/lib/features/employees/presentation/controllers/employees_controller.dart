import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../domain/entities/employee.dart';
import '../../domain/repositories/employee_repository.dart';
import '../states/employees_state.dart';

class EmployeesController extends StateNotifier<EmployeesState> {
  EmployeesController(this._repository, this._companyId)
    : super(const EmployeesState());

  final EmployeeRepository _repository;
  final String _companyId;

  Future<void> load() async {
    state = state.copyWith(status: EmployeesStatus.loading, clearError: true);
    final result = await _repository.getByCompany(_companyId);
    state = switch (result) {
      Success(:final data) => state.copyWith(
        status: EmployeesStatus.success,
        employees: data,
        filtered: await _filter(data),
      ),
      Error(:final failure) => state.copyWith(
        status: EmployeesStatus.error,
        errorMessage: failure.message,
      ),
    };
  }

  Future<void> setSearch(String query) async {
    state = state.copyWith(searchQuery: query);
    await _refreshFiltered();
  }

  Future<void> setDepartmentFilter(String? department) async {
    state = state.copyWith(
      departmentFilter: department,
      clearDepartment: department == null || department.isEmpty,
    );
    await _refreshFiltered();
  }

  Future<void> setRoleFilter(EmployeeRole? role) async {
    state = state.copyWith(roleFilter: role, clearRole: role == null);
    await _refreshFiltered();
  }

  Future<void> setStatusFilter(EmployeeStatus? status) async {
    state = state.copyWith(statusFilter: status, clearStatus: status == null);
    await _refreshFiltered();
  }

  Future<void> clearFilters() async {
    state = state.copyWith(
      searchQuery: '',
      clearDepartment: true,
      clearRole: true,
      clearStatus: true,
    );
    await _refreshFiltered();
  }

  Future<bool> deleteEmployee(String id) async {
    state = state.copyWith(isDeleting: true, clearError: true);
    final result = await _repository.delete(id);
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

  Future<void> _refreshFiltered() async {
    final result = await _repository.search(
      companyId: _companyId,
      query: state.searchQuery,
      department: state.departmentFilter,
      role: state.roleFilter,
      status: state.statusFilter,
    );
    state = switch (result) {
      Success(:final data) => state.copyWith(filtered: data),
      Error(:final failure) => state.copyWith(errorMessage: failure.message),
    };
  }

  Future<List<Employee>> _filter(List<Employee> source) async {
    final result = await _repository.search(
      companyId: _companyId,
      query: state.searchQuery,
      department: state.departmentFilter,
      role: state.roleFilter,
      status: state.statusFilter,
    );
    return switch (result) {
      Success(:final data) => data,
      Error() => source,
    };
  }
}
