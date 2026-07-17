import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/rbac/app_permission.dart';
import '../../../../core/rbac/rbac_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/states/auth_session_state.dart';
import '../controllers/company_context_controller.dart';
import '../states/company_context_state.dart';
import 'organization_repository_provider.dart';

final companyContextProvider =
    StateNotifierProvider<CompanyContextController, CompanyContextState>((ref) {
      final controller = CompanyContextController(
        ref.watch(organizationRepositoryProvider),
      );

      ref.listen<AuthSessionState>(authSessionProvider, (previous, next) {
        controller.hydrate(next.session?.user);
      });

      controller.hydrate(ref.read(authSessionProvider).session?.user);
      return controller;
    });

final activeCompanyProvider = Provider((ref) {
  return ref.watch(companyContextProvider).activeCompany;
});

final canManageCompaniesProvider = Provider<bool>((ref) {
  return ref.watch(permissionSetProvider).can(AppPermission.createCompany);
});

final canSwitchCompanyProvider = Provider<bool>((ref) {
  final permissions = ref.watch(permissionSetProvider);
  final companies = ref.watch(companyContextProvider).companies;
  return permissions.can(AppPermission.switchCompany) && companies.length > 1;
});
