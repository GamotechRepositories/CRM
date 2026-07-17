import '../../../../core/error/result.dart';
import '../entities/employee.dart';

abstract class EmployeeRepository {
  Future<Result<List<Employee>>> getByCompany(String companyId);

  Future<Result<Employee>> getById(String id);

  Future<Result<Employee>> create(Employee employee);

  Future<Result<Employee>> update(Employee employee);

  Future<Result<void>> delete(String id);

  Future<Result<List<Employee>>> search({
    required String companyId,
    String query = '',
    String? department,
    EmployeeRole? role,
    EmployeeStatus? status,
  });
}
