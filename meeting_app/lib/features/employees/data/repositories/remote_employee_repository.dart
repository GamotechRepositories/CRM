import '../../../../core/error/error_handler.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/employee.dart';
import '../../domain/repositories/employee_repository.dart';
import '../datasources/employee_remote_datasource.dart';

class RemoteEmployeeRepository implements EmployeeRepository {
  RemoteEmployeeRepository(this._remote);

  final EmployeeRemoteDataSource _remote;

  @override
  Future<Result<List<Employee>>> getByCompany(String companyId) async {
    try {
      final list = await _remote.getEmployees()
        ..sort((a, b) => a.name.compareTo(b.name));
      return Success(list);
    } on Failure catch (failure) {
      return Error(failure);
    } catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'RemoteEmployee.getByCompany');
      return Error(ErrorHandler.mapException(error));
    }
  }

  @override
  Future<Result<Employee>> getById(String id) async {
    try {
      return Success(await _remote.getById(id));
    } on Failure catch (failure) {
      return Error(failure);
    } catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'RemoteEmployee.getById');
      return Error(ErrorHandler.mapException(error));
    }
  }

  @override
  Future<Result<Employee>> create(Employee employee) async {
    return const Error(
      ValidationFailure('Create employee from the CRM web admin for now'),
    );
  }

  @override
  Future<Result<Employee>> update(Employee employee) async {
    return const Error(
      ValidationFailure('Update employee from the CRM web admin for now'),
    );
  }

  @override
  Future<Result<void>> delete(String id) async {
    return const Error(
      ValidationFailure('Delete employee from the CRM web admin for now'),
    );
  }

  @override
  Future<Result<List<Employee>>> search({
    required String companyId,
    String query = '',
    String? department,
    EmployeeRole? role,
    EmployeeStatus? status,
  }) async {
    final result = await getByCompany(companyId);
    return switch (result) {
      Error(:final failure) => Error(failure),
      Success(:final data) => Success(
          data.where((e) {
            final q = query.trim().toLowerCase();
            final matchesQuery = q.isEmpty ||
                e.name.toLowerCase().contains(q) ||
                e.email.toLowerCase().contains(q) ||
                e.mobile.contains(q);
            final matchesDept =
                department == null || department.isEmpty || e.department == department;
            final matchesRole = role == null || e.role == role;
            final matchesStatus = status == null || e.status == status;
            return matchesQuery && matchesDept && matchesRole && matchesStatus;
          }).toList(),
        ),
    };
  }
}
