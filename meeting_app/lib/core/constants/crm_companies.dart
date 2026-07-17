/// CRM companies (tenants) available in central admin Create Team.
abstract final class CrmCompanies {
  static const Map<String, String> labels = {
    'adsResearchGlobal': 'Ads Research Global',
    'bangarProperties': 'Bangar Properties',
    'mahaProperties': 'Maha Properties',
    'salesTechReality': 'Sales Tech Reality',
  };

  static List<({String id, String name})> get all => labels.entries
      .map((e) => (id: e.key, name: e.value))
      .toList(growable: false);

  static String nameOf(String? id) {
    if (id == null || id.isEmpty || id == 'central') return '';
    return labels[id] ?? id;
  }

  static List<({String id, String name})> forTenantIds(List<String> ids) {
    if (ids.isEmpty) return all;
    return ids
        .where((id) => labels.containsKey(id))
        .map((id) => (id: id, name: labels[id]!))
        .toList(growable: false);
  }
}
