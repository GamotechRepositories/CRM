import '../config/company_config.dart';
import '../dashboard/dashboard_stats.dart';
import '../dashboard/employee_dashboard_stats.dart';
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

  /// Property tenants pass `viewerId` on leads; ARG does not.
  bool get usesLeadsViewerId => company.id != CompanyId.adsResearchGlobal;

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

  Future<Map<String, dynamic>> fetchMyProfile(String employeeId) =>
      getEmployeeProfile(employeeId);

  Future<Map<String, dynamic>> updateProfilePhoto(String employeeId, String profilePhoto) {
    return client.patchJson(
      '${CrmPaths.employeeProfilePhoto}/$employeeId/profile-photo',
      body: {'profilePhoto': profilePhoto},
    );
  }

  Future<List<Map<String, dynamic>>> _list(
    String path, {
    Map<String, String>? query,
    bool softFail = false,
  }) async {
    try {
      final res = await client.getJson(path, query: query);
      return _asMapList(res);
    } catch (_) {
      if (softFail) return [];
      rethrow;
    }
  }

  static List<Map<String, dynamic>> _asMapList(Map<String, dynamic> res) {
    final raw = res['data'] ?? res;
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchList(
    String path, {
    Map<String, String>? query,
    bool softFail = false,
  }) =>
      _list(path, query: query, softFail: softFail);

  Future<List<Map<String, dynamic>>> fetchLeads({String? viewerId}) {
    final query = (usesLeadsViewerId && viewerId != null && viewerId.isNotEmpty)
        ? {'viewerId': viewerId}
        : null;
    return _list(CrmPaths.leads, query: query, softFail: true);
  }

  Future<List<Map<String, dynamic>>> fetchEmployees() => _list(CrmPaths.employees);

  Future<List<Map<String, dynamic>>> fetchClients() => _list(CrmPaths.clients);

  Future<List<Map<String, dynamic>>> fetchProjects() => _list(CrmPaths.projects);

  Future<List<Map<String, dynamic>>> fetchMyProjects(String employeeId) =>
      _list(CrmPaths.projectsMy, query: {'employeeId': employeeId});

  Future<List<Map<String, dynamic>>> fetchEmployeesAvailability({
    required String date,
    String? excludeTaskId,
  }) {
    final query = <String, String>{'date': date};
    if (excludeTaskId != null && excludeTaskId.isNotEmpty) {
      query['excludeTaskId'] = excludeTaskId;
    }
    return _list(CrmPaths.employeesAvailability, query: query, softFail: true);
  }

  Future<Map<String, dynamic>> createTask(Map<String, dynamic> body) =>
      client.postJson(CrmPaths.tasks, body: body);

  Future<List<Map<String, dynamic>>> fetchTasks({Map<String, String>? query}) =>
      _list(CrmPaths.tasks, query: query, softFail: true);

  Future<Map<String, dynamic>> fetchTaskById(String taskId) =>
      client.getJson('${CrmPaths.tasks}/$taskId');

  Future<Map<String, dynamic>> updateTask(String taskId, Map<String, dynamic> body) async {
    final res = await client.putJson('${CrmPaths.tasks}/$taskId', body: body);
    final task = res['task'];
    if (task is Map) return Map<String, dynamic>.from(task);
    return res;
  }

  Future<List<Map<String, dynamic>>> fetchLeave({String? employeeId}) {
    final query = (employeeId != null && employeeId.isNotEmpty) ? {'employeeId': employeeId} : null;
    return _list(CrmPaths.leave, query: query, softFail: true);
  }

  Future<Map<String, dynamic>> createLeave({
    required String employeeId,
    required String leaveType,
    required String startDate,
    required String endDate,
    String reason = '',
  }) =>
      client.postJson(CrmPaths.leave, body: {
        'employee': employeeId,
        'leaveType': leaveType,
        'startDate': startDate,
        'endDate': endDate,
        'reason': reason,
      });

  Future<Map<String, dynamic>> updateLeaveStatus(
    String leaveId, {
    required String action,
    required String actorId,
    String comment = '',
  }) =>
      client.patchJson('${CrmPaths.leave}/$leaveId/status', body: {
        'action': action,
        'actorId': actorId,
        if (comment.isNotEmpty) 'comment': comment,
      });

  Future<List<Map<String, dynamic>>> fetchBillings() => _list(CrmPaths.billing, softFail: true);

  Future<List<Map<String, dynamic>>> fetchProperties() =>
      _list(CrmPaths.properties, softFail: true);

  Future<List<Map<String, dynamic>>> fetchAnnouncements({Map<String, String>? query}) =>
      _list(CrmPaths.announcements, query: query, softFail: true);

  /// Tasks, leads, and announcements for employee `/dashboard`.
  Future<EmployeeDashboardStats> fetchEmployeeDashboard({required String employeeId}) async {
    final results = await Future.wait([
      fetchTasks(query: {'employeeId': employeeId}),
      fetchLeads(viewerId: employeeId),
      fetchAnnouncements(query: {'active': 'true'}),
    ]);
    return EmployeeDashboardStats.fromLists(
      tasks: results[0],
      leads: results[1],
      announcements: results[2],
    );
  }

  Future<List<Map<String, dynamic>>> fetchAttendanceByMonth({
    required String month,
    String? employeeId,
  }) {
    final query = <String, String>{'month': month};
    if (employeeId != null && employeeId.isNotEmpty) {
      query['employeeId'] = employeeId;
    }
    return _list(CrmPaths.attendanceByMonth, query: query, softFail: true);
  }

  Future<List<Map<String, dynamic>>> fetchAttendanceToday({
    String? date,
    String? employeeId,
  }) {
    final query = <String, String>{};
    if (date != null && date.isNotEmpty) query['date'] = date;
    if (employeeId != null && employeeId.isNotEmpty) query['employeeId'] = employeeId;
    return _list(CrmPaths.attendanceToday, query: query.isEmpty ? null : query, softFail: true);
  }

  Future<Map<String, dynamic>> checkIn({
    required String employeeId,
    required double latitude,
    required double longitude,
    required String address,
  }) =>
      client.postJson(CrmPaths.attendanceCheckIn, body: {
        'employee': employeeId,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
      });

  Future<Map<String, dynamic>> checkOut({
    required String employeeId,
    required double latitude,
    required double longitude,
    required String address,
  }) =>
      client.postJson(CrmPaths.attendanceCheckOut, body: {
        'employee': employeeId,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
      });

  Future<Map<String, dynamic>> startBreak({required String employeeId}) =>
      client.postJson(CrmPaths.attendanceBreakStart, body: {'employee': employeeId});

  Future<Map<String, dynamic>> endBreak({required String employeeId}) =>
      client.postJson(CrmPaths.attendanceBreakEnd, body: {'employee': employeeId});

  Future<Map<String, dynamic>> startMeeting({required String employeeId}) =>
      client.postJson(CrmPaths.attendanceMeetingStart, body: {'employee': employeeId});

  Future<Map<String, dynamic>> endMeeting({required String employeeId}) =>
      client.postJson(CrmPaths.attendanceMeetingEnd, body: {'employee': employeeId});

  Future<Map<String, dynamic>?> fetchEmployeeById(String employeeId) async {
    try {
      final res = await client.getJson('${CrmPaths.employees}/$employeeId');
      final emp = res['employee'] ?? res;
      if (emp is Map) return Map<String, dynamic>.from(emp);
    } catch (_) {}
    return null;
  }

  Future<List<Map<String, dynamic>>> fetchAttendanceForEmployee(String employeeId) =>
      _list(CrmPaths.attendanceForEmployee(employeeId), softFail: true);

  /// Same 7 list endpoints as web `/admin-dashboard`, for the selected company.
  Future<DashboardStats> fetchAdminDashboard({String? viewerId}) async {
    final leadsQuery = (usesLeadsViewerId && viewerId != null && viewerId.isNotEmpty)
        ? {'viewerId': viewerId}
        : null;

    final results = await Future.wait([
      _list(CrmPaths.employees),
      _list(CrmPaths.clients),
      _list(CrmPaths.projects),
      _list(CrmPaths.leads, query: leadsQuery, softFail: true),
      _list(CrmPaths.tasks, softFail: true),
      _list(CrmPaths.billing, softFail: true),
      _list(CrmPaths.leave, softFail: true),
    ]);

    return DashboardStats.fromLists(
      employees: results[0],
      clients: results[1],
      projects: results[2],
      leads: results[3],
      tasks: results[4],
      billings: results[5],
      leaves: results[6],
    );
  }
}
