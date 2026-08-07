import '../config/company_config.dart';
import 'api_client.dart';
import 'crm_paths.dart';

/// Bangar Properties APIs — base from `BANGAR_PROPERTIES_API_URL`.
/// Mirrors `bangarProperties/src/api/axios.js`.
class BangarPropertiesApi {
  BangarPropertiesApi([ApiClient? client])
      : client = client ??
            ApiClient(company: CompanyConfig.byId(CompanyId.bangarProperties)!);

  final ApiClient client;

  static CompanyConfig get company =>
      CompanyConfig.byId(CompanyId.bangarProperties)!;

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

  Future<Map<String, dynamic>> getLeads(String viewerId) =>
      client.getJson(CrmPaths.leads, query: {'viewerId': viewerId});
}
