import '../../../companies/domain/entities/company.dart';
import '../../../employees/domain/entities/employee.dart';
import '../../domain/organization_constants.dart';

/// Builds the demo Boss portfolio and per-company org charts.
abstract final class DemoOrganizationFactory {
  static List<Company> companies({required DateTime now}) {
    return OrganizationConstants.demoCompanies.map((spec) {
      return Company(
        id: spec.id,
        ownerId: OrganizationConstants.bossId,
        name: spec.name,
        industry: spec.industry,
        address: spec.address,
        website: spec.website,
        email: spec.email,
        phone: spec.phone,
        employeeCount: spec.employeeCount,
        colorValue: spec.colorValue,
        status: CompanyStatus.active,
        logoIcon: spec.logoIcon,
        createdAt: now,
        updatedAt: now,
      );
    }).toList();
  }

  static List<Employee> employees({required DateTime now}) {
    final list = <Employee>[];
    var mobileSeq = 9000000001;

    for (final spec in OrganizationConstants.demoCompanies) {
      final prefix = spec.id.replaceFirst('co_', '');

      final eaId = 'emp_${prefix}_ea';
      final mgr1Id = 'emp_${prefix}_mgr1';
      final mgr2Id = 'emp_${prefix}_mgr2';
      final tl1Id = 'emp_${prefix}_tl1';
      final tl2Id = 'emp_${prefix}_tl2';

      list.addAll([
        _emp(
          id: eaId,
          companyId: spec.id,
          name: '${_short(spec.name)} EA',
          mobile: '${mobileSeq++}',
          email: 'ea@$prefix.example',
          department: 'Executive',
          designation: 'Executive Assistant',
          role: EmployeeRole.executiveAssistant,
          color: 0xFF0369A1,
          icon: 'badge',
          now: now,
        ),
        _emp(
          id: mgr1Id,
          companyId: spec.id,
          name: '${_short(spec.name)} Ops Manager',
          mobile: '${mobileSeq++}',
          email: 'ops.manager@$prefix.example',
          department: 'Operations',
          designation: 'Department Manager',
          role: EmployeeRole.manager,
          color: 0xFF0F766E,
          icon: 'engineering',
          now: now,
        ),
        _emp(
          id: mgr2Id,
          companyId: spec.id,
          name: '${_short(spec.name)} Sales Manager',
          mobile: '${mobileSeq++}',
          email: 'sales.manager@$prefix.example',
          department: 'Sales',
          designation: 'Department Manager',
          role: EmployeeRole.manager,
          color: 0xFFC2410C,
          icon: 'sales',
          now: now,
        ),
        _emp(
          id: tl1Id,
          companyId: spec.id,
          name: '${_short(spec.name)} Ops Lead',
          mobile: '${mobileSeq++}',
          email: 'ops.lead@$prefix.example',
          department: 'Operations',
          designation: 'Team Lead',
          role: EmployeeRole.teamLead,
          managerId: mgr1Id,
          color: 0xFF7C3AED,
          icon: 'star',
          now: now,
        ),
        _emp(
          id: tl2Id,
          companyId: spec.id,
          name: '${_short(spec.name)} Sales Lead',
          mobile: '${mobileSeq++}',
          email: 'sales.lead@$prefix.example',
          department: 'Sales',
          designation: 'Team Lead',
          role: EmployeeRole.teamLead,
          managerId: mgr2Id,
          color: 0xFFBE123C,
          icon: 'star',
          now: now,
        ),
        _emp(
          id: 'emp_${prefix}_e1',
          companyId: spec.id,
          name: '${_short(spec.name)} Associate A',
          mobile: '${mobileSeq++}',
          email: 'associate.a@$prefix.example',
          department: 'Operations',
          designation: 'Associate',
          role: EmployeeRole.employee,
          managerId: tl1Id,
          color: 0xFF475569,
          icon: 'person',
          now: now,
        ),
        _emp(
          id: 'emp_${prefix}_e2',
          companyId: spec.id,
          name: '${_short(spec.name)} Associate B',
          mobile: '${mobileSeq++}',
          email: 'associate.b@$prefix.example',
          department: 'Sales',
          designation: 'Senior Associate',
          role: EmployeeRole.employee,
          managerId: tl2Id,
          color: 0xFF4F46E5,
          icon: 'person',
          now: now,
        ),
      ]);
    }

    return list;
  }

  static String _short(String name) {
    final first = name.split(' ').first;
    return first.length > 12 ? first.substring(0, 12) : first;
  }

  static Employee _emp({
    required String id,
    required String companyId,
    required String name,
    required String mobile,
    required String email,
    required String department,
    required String designation,
    required EmployeeRole role,
    required int color,
    required String icon,
    required DateTime now,
    String? managerId,
  }) {
    return Employee(
      id: id,
      companyId: companyId,
      name: name,
      mobile: mobile,
      email: email,
      department: department,
      designation: designation,
      role: role,
      reportingManagerId: managerId,
      status: EmployeeStatus.active,
      avatarColorValue: color,
      avatarIcon: icon,
      createdAt: now,
      updatedAt: now,
    );
  }
}
