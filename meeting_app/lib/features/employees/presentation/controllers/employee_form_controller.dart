import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/entities/employee.dart';
import '../../domain/repositories/employee_repository.dart';
import '../states/employee_form_state.dart';

class EmployeeFormController extends StateNotifier<EmployeeFormState> {
  EmployeeFormController({
    required EmployeeRepository repository,
    required String companyId,
    Employee? existing,
    List<Employee> managerOptions = const [],
  }) : _repository = repository,
       super(
         existing != null
             ? EmployeeFormState.fromEmployee(
                 existing,
                 managerOptions: managerOptions
                     .where((e) => e.id != existing.id)
                     .toList(),
               )
             : EmployeeFormState(
                 mode: EmployeeFormMode.create,
                 companyId: companyId,
                 managerOptions: managerOptions,
               ),
       );

  final EmployeeRepository _repository;

  void updateName(String v) =>
      state = state.copyWith(name: v, clearError: true);
  void updateMobile(String v) =>
      state = state.copyWith(mobile: v, clearError: true);
  void updateEmail(String v) =>
      state = state.copyWith(email: v, clearError: true);
  void updateDepartment(String v) =>
      state = state.copyWith(department: v, clearError: true);
  void updateDesignation(String v) =>
      state = state.copyWith(designation: v, clearError: true);
  void updateRole(EmployeeRole v) =>
      state = state.copyWith(role: v, clearError: true);
  void updateManager(String? v) => state = state.copyWith(
    reportingManagerId: v,
    clearManager: v == null || v.isEmpty,
    clearError: true,
  );
  void updateStatus(EmployeeStatus v) =>
      state = state.copyWith(employeeStatus: v, clearError: true);
  void updateAvatarColor(int v) =>
      state = state.copyWith(avatarColorValue: v, clearError: true);
  void updateAvatarIcon(String v) =>
      state = state.copyWith(avatarIcon: v, clearError: true);

  String? validate() {
    if (state.name.trim().isEmpty) return 'Name is required';
    final mobileError = Validators.mobile(state.mobile);
    if (mobileError != null) return mobileError;
    final emailError = Validators.email(state.email);
    if (emailError != null) return emailError;
    if (state.department.trim().isEmpty) return 'Department is required';
    if (state.designation.trim().isEmpty) return 'Designation is required';
    if (state.reportingManagerId == state.employeeId) {
      return 'Employee cannot report to themselves';
    }
    return null;
  }

  Future<Employee?> submit() async {
    final validationError = validate();
    if (validationError != null) {
      state = state.copyWith(
        status: EmployeeFormStatus.error,
        errorMessage: validationError,
      );
      return null;
    }

    state = state.copyWith(
      status: EmployeeFormStatus.loading,
      clearError: true,
    );
    final now = DateTime.now();

    final employee = Employee(
      id: state.employeeId ?? 'emp_${now.millisecondsSinceEpoch}',
      companyId: state.companyId,
      name: state.name.trim(),
      mobile: Validators.normalizeMobile(state.mobile),
      email: state.email.trim(),
      department: state.department.trim(),
      designation: state.designation.trim(),
      role: state.role,
      reportingManagerId: state.reportingManagerId,
      status: state.employeeStatus,
      avatarColorValue: state.avatarColorValue,
      avatarIcon: state.avatarIcon,
      createdAt: state.createdAt ?? now,
      updatedAt: now,
    );

    final result = state.mode == EmployeeFormMode.create
        ? await _repository.create(employee)
        : await _repository.update(employee);

    return switch (result) {
      Success(:final data) => () {
        state = state.copyWith(status: EmployeeFormStatus.success);
        return data;
      }(),
      Error(:final failure) => () {
        state = state.copyWith(
          status: EmployeeFormStatus.error,
          errorMessage: failure.message,
        );
        return null;
      }(),
    };
  }
}
