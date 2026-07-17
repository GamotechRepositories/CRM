import 'package:equatable/equatable.dart';

import '../../../auth/domain/entities/auth_user.dart';
import '../../../companies/domain/entities/company.dart';
import '../../../employees/domain/entities/employee.dart';

/// Resolved company access scope for the signed-in user.
///
/// Authorization for UI actions must go through RBAC permissions.
class OrganizationAccess extends Equatable {
  const OrganizationAccess({
    required this.user,
    required this.accessibleCompanies,
    required this.activeCompanyId,
  });

  final AuthUser user;
  final List<Company> accessibleCompanies;
  final String? activeCompanyId;

  Company? get activeCompany {
    if (accessibleCompanies.isEmpty) return null;
    if (activeCompanyId == null) return accessibleCompanies.first;
    return accessibleCompanies.cast<Company?>().firstWhere(
      (c) => c!.id == activeCompanyId,
      orElse: () => accessibleCompanies.first,
    );
  }

  bool canAccessCompany(String companyId) =>
      accessibleCompanies.any((c) => c.id == companyId);

  /// Members stay locked to their home company (data-scope rule).
  bool get isCompanyLocked => user.appRole == AppRole.member;

  @override
  List<Object?> get props => [user, accessibleCompanies, activeCompanyId];
}

/// Lightweight org directory lookup used by auth + access layer.
class OrgDirectoryLookup extends Equatable {
  const OrgDirectoryLookup({required this.employee, required this.company});

  final Employee employee;
  final Company company;

  @override
  List<Object?> get props => [employee, company];
}
