import '../config/company_config.dart';
import 'ads_research_global_api.dart';
import 'api_client.dart';
import 'bangar_properties_api.dart';
import 'crm_paths.dart';
import 'maha_properties_api.dart';
import 'sales_tech_reality_api.dart';

/// Factory that routes calls to the selected company's API module.
class CompanyApi {
  CompanyApi(this.company) : client = ApiClient(company: company);

  final CompanyConfig company;
  final ApiClient client;

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) {
    switch (company.id) {
      case CompanyId.salesTechReality:
        return SalesTechRealityApi(client).login(email: email, password: password);
      case CompanyId.bangarProperties:
        return BangarPropertiesApi(client).login(email: email, password: password);
      case CompanyId.mahaProperties:
        return MahaPropertiesApi(client).login(email: email, password: password);
      case CompanyId.adsResearchGlobal:
        return AdsResearchGlobalApi(client).login(email: email, password: password);
    }
  }

  Future<Map<String, dynamic>> getMyTasks(String employeeId) {
    return client.getJson(CrmPaths.tasks, query: {'employeeId': employeeId});
  }

  Future<Map<String, dynamic>> getEmployeeProfile(String employeeId) {
    return client.getJson('${CrmPaths.employeeProfile}/$employeeId/profile');
  }
}
