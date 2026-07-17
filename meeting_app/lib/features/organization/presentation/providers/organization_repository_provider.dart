import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/hive_service.dart';
import '../../../companies/data/datasources/company_local_datasource.dart';
import '../../../employees/data/datasources/employee_local_datasource.dart';
import '../../data/repositories/local_organization_repository.dart';
import '../../domain/repositories/organization_repository.dart';

final organizationRepositoryProvider = Provider<OrganizationRepository>((ref) {
  final hive = ref.watch(hiveServiceProvider);
  return LocalOrganizationRepository(
    hive: hive,
    companies: CompanyLocalDataSource(hive),
    employees: EmployeeLocalDataSource(hive),
  );
});
