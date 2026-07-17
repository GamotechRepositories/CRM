import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/hive_service.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../organization/presentation/providers/organization_repository_provider.dart';
import '../../data/datasources/company_local_datasource.dart';
import '../../data/repositories/local_company_repository.dart';
import '../../domain/entities/company.dart';
import '../../domain/repositories/company_repository.dart';
import '../controllers/companies_controller.dart';
import '../controllers/company_detail_controller.dart';
import '../controllers/company_form_controller.dart';
import '../states/companies_state.dart';
import '../states/company_detail_state.dart';
import '../states/company_form_state.dart';

final companyLocalDataSourceProvider = Provider<CompanyLocalDataSource>((ref) {
  return CompanyLocalDataSource(ref.watch(hiveServiceProvider));
});

final companyRepositoryProvider = Provider<CompanyRepository>((ref) {
  return LocalCompanyRepository(ref.watch(companyLocalDataSourceProvider));
});

final companiesControllerProvider =
    StateNotifierProvider.autoDispose<CompaniesController, CompaniesState>((
      ref,
    ) {
      final user = ref.watch(authSessionProvider).session?.user;
      final controller = CompaniesController(
        companyRepository: ref.watch(companyRepositoryProvider),
        organizationRepository: ref.watch(organizationRepositoryProvider),
        user: user,
      );
      controller.load();
      return controller;
    });

final companyDetailControllerProvider = StateNotifierProvider.autoDispose
    .family<CompanyDetailController, CompanyDetailState, String>((
      ref,
      companyId,
    ) {
      final controller = CompanyDetailController(
        ref.watch(companyRepositoryProvider),
        companyId,
      );
      controller.load();
      return controller;
    });

final companyFormControllerProvider = StateNotifierProvider.autoDispose
    .family<CompanyFormController, CompanyFormState, CompanyFormArgs>((
      ref,
      args,
    ) {
      final user = ref.watch(authSessionProvider).session?.user;
      return CompanyFormController(
        repository: ref.watch(companyRepositoryProvider),
        ownerId: user?.id ?? 'anonymous',
        existing: args.existing,
      );
    });

class CompanyFormArgs {
  const CompanyFormArgs({this.existing});

  final Company? existing;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompanyFormArgs &&
          runtimeType == other.runtimeType &&
          existing?.id == other.existing?.id;

  @override
  int get hashCode => existing?.id.hashCode ?? 0;
}
