import '../../../../core/constants/storage_keys.dart';
import '../../../../core/error/error_handler.dart';
import '../../../../core/error/result.dart';
import '../../../../core/storage/hive_service.dart';
import '../../../../core/utils/logger.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../companies/data/datasources/company_local_datasource.dart';
import '../../../companies/data/models/company_model.dart';
import '../../../companies/domain/entities/company.dart';
import '../../../employees/data/datasources/employee_local_datasource.dart';
import '../../../employees/data/models/employee_model.dart';
import '../../../employees/domain/entities/employee.dart';
import '../../domain/entities/organization_access.dart';
import '../../domain/organization_constants.dart';
import '../../domain/repositories/organization_repository.dart';
import '../demo/demo_organization_factory.dart';

class LocalOrganizationRepository implements OrganizationRepository {
  LocalOrganizationRepository({
    required HiveService hive,
    required CompanyLocalDataSource companies,
    required EmployeeLocalDataSource employees,
  }) : _hive = hive,
       _companies = companies,
       _employees = employees;

  final HiveService _hive;
  final CompanyLocalDataSource _companies;
  final EmployeeLocalDataSource _employees;

  @override
  Future<Result<void>> ensureDemoData() async {
    try {
      final version = _hive.get<int>(StorageKeys.orgSeedVersion) ?? 0;
      final existingCompanies = _companies.readAll();
      final needsSeed =
          version < OrganizationConstants.seedVersion ||
          existingCompanies.isEmpty;

      if (!needsSeed) {
        return const Success(null);
      }

      final now = DateTime.now();
      final companies = DemoOrganizationFactory.companies(now: now);
      final employees = DemoOrganizationFactory.employees(now: now);

      await _companies.writeAll(
        companies.map(CompanyModel.fromEntity).toList(),
      );
      await _employees.writeAll(
        employees.map(EmployeeModel.fromEntity).toList(),
      );
      await _hive.put(
        StorageKeys.orgSeedVersion,
        OrganizationConstants.seedVersion,
      );
      await _hive.put(
        StorageKeys.activeCompanyId,
        OrganizationConstants.demoCompanies.first.id,
      );

      AppLogger.info(
        'Demo org seeded · ${companies.length} companies · ${employees.length} employees',
      );
      return const Success(null);
    } catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'Org.ensureDemoData');
      return Error(ErrorHandler.mapException(error));
    }
  }

  @override
  Future<Result<List<Company>>> getAccessibleCompanies(AuthUser user) async {
    try {
      final all = _companies.readAll().map((e) => e.toEntity()).toList();

      if (user.appRole == AppRole.boss) {
        final owned = all.where((c) => c.ownerId == user.id).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        return Success(owned);
      }

      final homeId = user.homeCompanyId;
      if (homeId == null) return const Success([]);
      final match = all.where((c) => c.id == homeId).toList();
      return Success(match);
    } catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'Org.getAccessible');
      return Error(ErrorHandler.mapException(error));
    }
  }

  @override
  Future<Result<OrgDirectoryLookup?>> findMemberByMobile(String mobile) async {
    try {
      final digits = mobile.replaceAll(RegExp(r'\D'), '');
      final employees = _employees.readAll().map((e) => e.toEntity());
      Employee? employee;
      for (final e in employees) {
        if (e.mobile == digits) {
          employee = e;
          break;
        }
      }
      if (employee == null) return const Success(null);

      final companyModel = _companies.readById(employee.companyId);
      if (companyModel == null) return const Success(null);

      return Success(
        OrgDirectoryLookup(
          employee: employee,
          company: companyModel.toEntity(),
        ),
      );
    } catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'Org.findMember');
      return Error(ErrorHandler.mapException(error));
    }
  }

  @override
  Future<Result<Employee?>> getEmployeeById(String id) async {
    try {
      final model = _employees.readById(id);
      return Success(model?.toEntity());
    } catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'Org.getEmployee');
      return Error(ErrorHandler.mapException(error));
    }
  }

  @override
  Future<String?> getActiveCompanyId() async {
    return _hive.get<String>(StorageKeys.activeCompanyId);
  }

  @override
  Future<Result<void>> setActiveCompanyId(String companyId) async {
    try {
      await _hive.put(StorageKeys.activeCompanyId, companyId);
      return const Success(null);
    } catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'Org.setActiveCompany');
      return Error(ErrorHandler.mapException(error));
    }
  }
}
