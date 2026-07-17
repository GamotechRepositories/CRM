import '../../../../core/error/result.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../companies/domain/entities/company.dart';
import '../../../employees/domain/entities/employee.dart';
import '../entities/organization_access.dart';

abstract class OrganizationRepository {
  /// Ensures demo companies + org chart exist (idempotent).
  Future<Result<void>> ensureDemoData();

  Future<Result<List<Company>>> getAccessibleCompanies(AuthUser user);

  Future<Result<OrgDirectoryLookup?>> findMemberByMobile(String mobile);

  Future<Result<Employee?>> getEmployeeById(String id);

  Future<String?> getActiveCompanyId();

  Future<Result<void>> setActiveCompanyId(String companyId);
}
