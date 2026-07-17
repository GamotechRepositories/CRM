import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/rbac/app_permission.dart';
import '../../../../core/rbac/permission_set.dart';
import '../../../../core/rbac/system_role.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../domain/repositories/organization_repository.dart';
import '../states/company_context_state.dart';

class CompanyContextController extends StateNotifier<CompanyContextState> {
  CompanyContextController(this._organization)
    : super(const CompanyContextState());

  final OrganizationRepository _organization;

  Future<void> hydrate(AuthUser? user) async {
    if (user == null) {
      state = const CompanyContextState(status: CompanyContextStatus.ready);
      return;
    }

    state = state.copyWith(
      status: CompanyContextStatus.loading,
      user: user,
      clearError: true,
    );

    final companiesResult = await _organization.getAccessibleCompanies(user);
    switch (companiesResult) {
      case Error(:final failure):
        state = state.copyWith(
          status: CompanyContextStatus.error,
          errorMessage: failure.message,
        );
        return;
      case Success(:final data):
        var activeId = await _organization.getActiveCompanyId();
        final isMember = user.appRole == AppRole.member;
        if (isMember && user.homeCompanyId != null) {
          activeId = user.homeCompanyId;
          await _organization.setActiveCompanyId(user.homeCompanyId!);
        } else if (data.isNotEmpty) {
          final valid = data.any((c) => c.id == activeId);
          if (!valid) {
            activeId = data.first.id;
            await _organization.setActiveCompanyId(activeId);
          }
        } else {
          activeId = null;
        }

        state = state.copyWith(
          status: CompanyContextStatus.ready,
          companies: data,
          activeCompanyId: activeId,
        );
    }
  }

  Future<bool> switchCompany(String companyId) async {
    final user = state.user;
    if (user == null) return false;

    final permissions = PermissionSet.forRole(RoleResolver.fromAuthUser(user));
    if (!permissions.can(AppPermission.switchCompany)) return false;
    if (!state.companies.any((c) => c.id == companyId)) return false;

    state = state.copyWith(isSwitching: true, clearError: true);
    final result = await _organization.setActiveCompanyId(companyId);
    return switch (result) {
      Success() => () {
        state = state.copyWith(activeCompanyId: companyId, isSwitching: false);
        return true;
      }(),
      Error(:final failure) => () {
        state = state.copyWith(
          isSwitching: false,
          errorMessage: failure.message,
        );
        return false;
      }(),
    };
  }

  Future<void> refresh() => hydrate(state.user);
}
