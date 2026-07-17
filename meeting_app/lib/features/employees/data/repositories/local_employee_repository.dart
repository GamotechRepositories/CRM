import '../../../../core/error/error_handler.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/employee.dart';
import '../../domain/repositories/employee_repository.dart';
import '../datasources/employee_local_datasource.dart';
import '../models/employee_model.dart';

class LocalEmployeeRepository implements EmployeeRepository {
  LocalEmployeeRepository(this._local);

  final EmployeeLocalDataSource _local;

  static const _latency = Duration(milliseconds: 550);

  @override
  Future<Result<List<Employee>>> getByCompany(String companyId) async {
    await Future<void>.delayed(_latency);
    try {
      final list =
          _local
              .readAll()
              .where((e) => e.companyId == companyId)
              .map((e) => e.toEntity())
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
      return Success(list);
    } catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'Employee.getByCompany');
      return Error(ErrorHandler.mapException(error));
    }
  }

  @override
  Future<Result<Employee>> getById(String id) async {
    await Future<void>.delayed(_latency);
    try {
      final model = _local.readById(id);
      if (model == null) {
        return const Error(ValidationFailure('Employee not found'));
      }
      return Success(model.toEntity());
    } catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'Employee.getById');
      return Error(ErrorHandler.mapException(error));
    }
  }

  @override
  Future<Result<Employee>> create(Employee employee) async {
    await Future<void>.delayed(_latency);
    try {
      if (employee.name.trim().isEmpty) {
        return const Error(ValidationFailure('Name is required'));
      }
      final model = EmployeeModel.fromEntity(employee);
      await _local.upsert(model);
      return Success(model.toEntity());
    } catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'Employee.create');
      return Error(ErrorHandler.mapException(error));
    }
  }

  @override
  Future<Result<Employee>> update(Employee employee) async {
    await Future<void>.delayed(_latency);
    try {
      if (_local.readById(employee.id) == null) {
        return const Error(ValidationFailure('Employee not found'));
      }
      final updated = employee.copyWith(updatedAt: DateTime.now());
      final model = EmployeeModel.fromEntity(updated);
      await _local.upsert(model);
      return Success(model.toEntity());
    } catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'Employee.update');
      return Error(ErrorHandler.mapException(error));
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    await Future<void>.delayed(_latency);
    try {
      if (_local.readById(id) == null) {
        return const Error(ValidationFailure('Employee not found'));
      }
      await _local.delete(id);
      return const Success(null);
    } catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'Employee.delete');
      return Error(ErrorHandler.mapException(error));
    }
  }

  @override
  Future<Result<List<Employee>>> search({
    required String companyId,
    String query = '',
    String? department,
    EmployeeRole? role,
    EmployeeStatus? status,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    try {
      final q = query.trim().toLowerCase();
      final list =
          _local
              .readAll()
              .where((e) => e.companyId == companyId)
              .map((e) => e.toEntity())
              .where((e) {
                if (department != null &&
                    department.isNotEmpty &&
                    e.department != department) {
                  return false;
                }
                if (role != null && e.role != role) return false;
                if (status != null && e.status != status) return false;
                if (q.isEmpty) return true;
                return e.name.toLowerCase().contains(q) ||
                    e.email.toLowerCase().contains(q) ||
                    e.mobile.contains(q) ||
                    e.department.toLowerCase().contains(q) ||
                    e.designation.toLowerCase().contains(q) ||
                    e.role.label.toLowerCase().contains(q);
              })
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
      return Success(list);
    } catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'Employee.search');
      return Error(ErrorHandler.mapException(error));
    }
  }
}
