import 'app_env.dart';

enum CompanyId {
  salesTechReality,
  bangarProperties,
  mahaProperties,
  adsResearchGlobal,
}

/// Company metadata + base URL (from `.env`, mirrors each web CRM `VITE_API_URL`).
class CompanyConfig {
  const CompanyConfig({
    required this.id,
    required this.key,
    required this.displayName,
    required this.shortName,
    required this.envUrlKey,
  });

  final CompanyId id;
  final String key;
  final String displayName;
  final String shortName;
  final String envUrlKey;

  String get apiBaseUrl => AppEnv.require(envUrlKey);

  static const List<CompanyConfig> all = [
    CompanyConfig(
      id: CompanyId.salesTechReality,
      key: 'salesTechReality',
      displayName: 'Sales Tech Reality',
      shortName: 'STR',
      envUrlKey: 'SALES_TECH_REALITY_API_URL',
    ),
    CompanyConfig(
      id: CompanyId.bangarProperties,
      key: 'bangarProperties',
      displayName: 'Bangar Properties',
      shortName: 'Bangar',
      envUrlKey: 'BANGAR_PROPERTIES_API_URL',
    ),
    CompanyConfig(
      id: CompanyId.mahaProperties,
      key: 'mahaProperties',
      displayName: 'Maha Properties',
      shortName: 'Maha',
      envUrlKey: 'MAHA_PROPERTIES_API_URL',
    ),
    CompanyConfig(
      id: CompanyId.adsResearchGlobal,
      key: 'adsResearchGlobal',
      displayName: 'Ads Research Global',
      shortName: 'ARG',
      envUrlKey: 'ADS_RESEARCH_GLOBAL_API_URL',
    ),
  ];

  static CompanyConfig? byKey(String? key) {
    if (key == null || key.isEmpty) return null;
    for (final c in all) {
      if (c.key == key) return c;
    }
    return null;
  }

  static CompanyConfig? byId(CompanyId id) {
    for (final c in all) {
      if (c.id == id) return c;
    }
    return null;
  }
}
