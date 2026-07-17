/// Stable demo identity for the single Boss and seed data.
abstract final class OrganizationConstants {
  static const String bossId = 'boss_001';
  static const String bossMobile = '9876543210';
  static const String bossName = 'Roshan Boss';

  static const String demoOtp = '123456';

  /// Seed version — bump to force re-seed when demo schema changes.
  static const int seedVersion = 5;
  static const int meetingsSeedVersion = 5;

  static const List<DemoCompanySpec> demoCompanies = [
    DemoCompanySpec(
      id: 'co_apex',
      name: 'Apex Digital',
      chipLabel: 'Apex Digital',
      industry: 'Technology',
      colorValue: 0xFF1D4ED8,
      logoIcon: 'tech',
      address: 'Pune, Maharashtra',
      website: 'https://apexdigital.example',
      email: 'hello@apexdigital.example',
      phone: '0204001001',
      employeeCount: 48,
    ),
    DemoCompanySpec(
      id: 'co_abc',
      name: 'ABC Pvt Ltd',
      chipLabel: 'ABC Pvt Ltd',
      industry: 'Finance',
      colorValue: 0xFF0F766E,
      logoIcon: 'finance',
      address: 'Mumbai, Maharashtra',
      website: 'https://abc.example',
      email: 'contact@abc.example',
      phone: '0224002002',
      employeeCount: 120,
    ),
    DemoCompanySpec(
      id: 'co_xyz',
      name: 'XYZ Technologies',
      chipLabel: 'XYZ',
      industry: 'Technology',
      colorValue: 0xFF7C3AED,
      logoIcon: 'apartment',
      address: 'Bengaluru, Karnataka',
      website: 'https://xyztech.example',
      email: 'info@xyztech.example',
      phone: '0804003003',
      employeeCount: 86,
    ),
    DemoCompanySpec(
      id: 'co_def',
      name: 'DEF Industries',
      chipLabel: 'DEF',
      industry: 'Manufacturing',
      colorValue: 0xFFC2410C,
      logoIcon: 'factory',
      address: 'Chennai, Tamil Nadu',
      website: 'https://def.example',
      email: 'ops@def.example',
      phone: '0444004004',
      employeeCount: 210,
    ),
    DemoCompanySpec(
      id: 'co_pqr',
      name: 'PQR Solutions',
      chipLabel: 'PQR',
      industry: 'Consulting',
      colorValue: 0xFFBE123C,
      logoIcon: 'business',
      address: 'Nashik, Maharashtra',
      website: 'https://pqr.example',
      email: 'team@pqr.example',
      phone: '02534005005',
      employeeCount: 34,
    ),
  ];
}

class DemoCompanySpec {
  const DemoCompanySpec({
    required this.id,
    required this.name,
    required this.chipLabel,
    required this.industry,
    required this.colorValue,
    required this.logoIcon,
    required this.address,
    required this.website,
    required this.email,
    required this.phone,
    required this.employeeCount,
  });

  final String id;
  final String name;
  final String chipLabel;
  final String industry;
  final int colorValue;
  final String logoIcon;
  final String address;
  final String website;
  final String email;
  final String phone;
  final int employeeCount;
}
