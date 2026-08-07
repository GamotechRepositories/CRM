import '../config/company_config.dart';
import 'api_client.dart';
import 'crm_paths.dart';

/// Ads Research Global APIs — base from `ADS_RESEARCH_GLOBAL_API_URL`.
/// Mirrors `adsResearchGlobal/src/api/axios.js`.
class AdsResearchGlobalApi {
  AdsResearchGlobalApi([ApiClient? client])
      : client = client ??
            ApiClient(
                company: CompanyConfig.byId(CompanyId.adsResearchGlobal)!);

  final ApiClient client;

  static CompanyConfig get company =>
      CompanyConfig.byId(CompanyId.adsResearchGlobal)!;

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) {
    return client.postJson(CrmPaths.authLogin, body: {
      'email': email.trim(),
      'password': password,
    });
  }

  Future<Map<String, dynamic>> getEmployees() =>
      client.getJson(CrmPaths.employees);

  Future<Map<String, dynamic>> getMyTasks(String employeeId) =>
      client.getJson(CrmPaths.tasks, query: {'employeeId': employeeId});
}
