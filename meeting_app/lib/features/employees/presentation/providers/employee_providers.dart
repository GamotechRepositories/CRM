import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/hive_service.dart';
import '../../../companies/presentation/providers/company_providers.dart';
import '../../data/datasources/employee_local_datasource.dart';
import '../../data/datasources/employee_remote_datasource.dart';
import '../../data/repositories/remote_employee_repository.dart';
import '../../domain/entities/employee.dart';
import '../../domain/repositories/employee_repository.dart';
import '../controllers/employee_detail_controller.dart';
import '../controllers/employee_form_controller.dart';
import '../controllers/employees_controller.dart';
import '../states/employee_detail_state.dart';
import '../states/employee_form_state.dart';
import '../states/employees_state.dart';

final employeeLocalDataSourceProvider = Provider<EmployeeLocalDataSource>((
  ref,
) {
  return EmployeeLocalDataSource(ref.watch(hiveServiceProvider));
});

final employeeRemoteDataSourceProvider = Provider<EmployeeRemoteDataSource>((
  ref,
) {
  return EmployeeRemoteDataSource(ref.watch(dioProvider));
});

final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  return RemoteEmployeeRepository(ref.watch(employeeRemoteDataSourceProvider));
});

final employeesControllerProvider = StateNotifierProvider.autoDispose
    .family<EmployeesController, EmployeesState, String>((ref, companyId) {
      final controller = EmployeesController(
        ref.watch(employeeRepositoryProvider),
        companyId,
      );
      controller.load();
      return controller;
    });

final employeeDetailControllerProvider = StateNotifierProvider.autoDispose
    .family<EmployeeDetailController, EmployeeDetailState, String>((
      ref,
      employeeId,
    ) {
      final controller = EmployeeDetailController(
        employeeRepository: ref.watch(employeeRepositoryProvider),
        companyRepository: ref.watch(companyRepositoryProvider),
        employeeId: employeeId,
      );
      controller.load();
      return controller;
    });

final employeeFormControllerProvider = StateNotifierProvider.autoDispose
    .family<EmployeeFormController, EmployeeFormState, EmployeeFormArgs>((
      ref,
      args,
    ) {
      return EmployeeFormController(
        repository: ref.watch(employeeRepositoryProvider),
        companyId: args.companyId,
        existing: args.existing,
        managerOptions: args.managerOptions,
      );
    });

class EmployeeFormArgs {
  const EmployeeFormArgs({
    required this.companyId,
    this.existing,
    this.managerOptions = const [],
  });

  final String companyId;
  final Employee? existing;
  final List<Employee> managerOptions;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmployeeFormArgs &&
          runtimeType == other.runtimeType &&
          companyId == other.companyId &&
          existing?.id == other.existing?.id;

  @override
  int get hashCode => Object.hash(companyId, existing?.id);
}
