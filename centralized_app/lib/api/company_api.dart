import '../config/company_config.dart';
import '../dashboard/dashboard_stats.dart';
import '../dashboard/employee_dashboard_stats.dart';
import 'ads_research_global_api.dart';
import 'api_client.dart';
import 'bangar_properties_api.dart';
import 'crm_paths.dart';
import 'maha_properties_api.dart';
import 'sales_tech_reality_api.dart';

class ChatMessagesPage {
  const ChatMessagesPage({
    required this.messages,
    this.day,
    this.hasOlder = false,
  });

  final List<Map<String, dynamic>> messages;
  final String? day;
  final bool hasOlder;
}

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

  Future<List<Map<String, dynamic>>> fetchLeads({
    String? viewerId,
    Map<String, String>? filters,
  }) {
    final query = <String, String>{};
    if (usesLeadsViewerId && viewerId != null && viewerId.isNotEmpty) {
      query['viewerId'] = viewerId;
    }
    if (filters != null) {
      filters.forEach((k, v) {
        if (v.trim().isNotEmpty) query[k] = v.trim();
      });
    }
    return _list(CrmPaths.leads, query: query.isEmpty ? null : query, softFail: true);
  }

  Future<Map<String, dynamic>> createLead(Map<String, dynamic> body) {
    return client.postJson(CrmPaths.leads, body: body);
  }

  Future<Map<String, dynamic>> updateLead(String id, Map<String, dynamic> body) {
    return client.putJson('${CrmPaths.leads}/$id', body: body);
  }

  Future<Map<String, dynamic>> fetchLeadById(String id) {
    return client.getJson('${CrmPaths.leads}/$id');
  }

  Future<Map<String, dynamic>> addLeadFollowUp(String id, Map<String, dynamic> body) {
    return client.postJson('${CrmPaths.leads}/$id/follow-up', body: body);
  }

  Future<Map<String, dynamic>> fetchDistributionPreview(String actorId) {
    return client.getJson('${CrmPaths.leads}/distribution-preview', query: {'actorId': actorId});
  }

  Future<Map<String, dynamic>> distributeLeads(String distributedBy) {
    return client.postJson('${CrmPaths.leads}/distribute', body: {'distributedBy': distributedBy});
  }

  Future<Map<String, dynamic>> importLeadsCsv({
    required String csvText,
    required String fileName,
    required String importedBy,
  }) {
    return client.postJson('${CrmPaths.leads}/import-csv', body: {
      'csvText': csvText,
      'fileName': fileName,
      'importedBy': importedBy,
    });
  }


  Future<List<Map<String, dynamic>>> fetchEmployees() => _list(CrmPaths.employees);

  Future<Map<String, dynamic>> createEmployee(Map<String, dynamic> body) async {
    return client.postJson(CrmPaths.employees, body: body);
  }

  Future<Map<String, dynamic>> updateEmployee(String id, Map<String, dynamic> body) async {
    return client.putJson('${CrmPaths.employees}/$id', body: body);
  }

  Future<void> deleteEmployee(String id) async {
    await client.deleteJson('${CrmPaths.employees}/$id');
  }

  Future<List<Map<String, dynamic>>> fetchAssets({Map<String, String>? query}) =>
      _list('/assets', query: query, softFail: true);

  Future<Map<String, dynamic>> createAsset(Map<String, dynamic> body) =>
      client.postJson('/assets', body: body);

  Future<Map<String, dynamic>> updateAsset(String id, Map<String, dynamic> body) =>
      client.putJson('/assets/$id', body: body);

  Future<void> deleteAsset(String id) =>
      client.deleteJson('/assets/$id');

  Future<Map<String, dynamic>> assignAsset(String assetId, String employeeId) =>
      client.putJson('/assets/$assetId/assign', body: {'assignedTo': employeeId});

  // --- FINANCE API METHODS ---
  Future<List<Map<String, dynamic>>> fetchBillings({Map<String, String>? query}) =>
      _list(CrmPaths.billing, query: query, softFail: true);

  Future<Map<String, dynamic>> createBilling(Map<String, dynamic> body) =>
      client.postJson(CrmPaths.billing, body: body);

  Future<Map<String, dynamic>> updateBilling(String id, Map<String, dynamic> body) =>
      client.putJson('${CrmPaths.billing}/$id', body: body);

  Future<void> deleteBilling(String id) =>
      client.deleteJson('${CrmPaths.billing}/$id');

  Future<List<Map<String, dynamic>>> fetchExpenses({Map<String, String>? query}) =>
      _list('/expenses', query: query, softFail: true);

  Future<Map<String, dynamic>> createExpense(Map<String, dynamic> body) =>
      client.postJson('/expenses', body: body);

  Future<Map<String, dynamic>> updateExpense(String id, Map<String, dynamic> body) =>
      client.putJson('/expenses/$id', body: body);

  Future<void> deleteExpense(String id) =>
      client.deleteJson('/expenses/$id');

  Future<List<Map<String, dynamic>>> fetchSalaries({Map<String, String>? query}) =>
      _list('/salaries', query: query, softFail: true);

  Future<Map<String, dynamic>> createSalary(Map<String, dynamic> body) =>
      client.postJson('/salaries', body: body);

  Future<Map<String, dynamic>> updateSalary(String id, Map<String, dynamic> body) =>
      client.putJson('/salaries/$id', body: body);

  Future<void> deleteSalary(String id) =>
      client.deleteJson('/salaries/$id');

  // --- COMPANIES & QUOTATIONS API METHODS ---
  Future<List<Map<String, dynamic>>> fetchCompanies({Map<String, String>? query}) =>
      _list('/companies', query: query, softFail: true);

  Future<Map<String, dynamic>> createCompanyRecord(Map<String, dynamic> body) =>
      client.postJson('/companies', body: body);

  Future<Map<String, dynamic>> updateCompanyRecord(String id, Map<String, dynamic> body) =>
      client.putJson('/companies/$id', body: body);

  Future<void> deleteCompanyRecord(String id) =>
      client.deleteJson('/companies/$id');

  Future<List<Map<String, dynamic>>> fetchQuotations({Map<String, String>? query}) =>
      _list('/quotations', query: query, softFail: true);

  Future<Map<String, dynamic>> createQuotation(Map<String, dynamic> body) =>
      client.postJson('/quotations', body: body);

  Future<Map<String, dynamic>> updateQuotation(String id, Map<String, dynamic> body) =>
      client.putJson('/quotations/$id', body: body);

  Future<void> deleteQuotation(String id) =>
      client.deleteJson('/quotations/$id');

  // --- DESIGNATIONS API METHODS ---
  Future<List<Map<String, dynamic>>> fetchDesignations({Map<String, String>? query}) =>
      _list('/designations', query: query, softFail: true);

  Future<Map<String, dynamic>> createDesignation(Map<String, dynamic> body) =>
      client.postJson('/designations', body: body);

  Future<Map<String, dynamic>> updateDesignation(String id, Map<String, dynamic> body) =>
      client.putJson('/designations/$id', body: body);

  Future<void> deleteDesignation(String id) =>
      client.deleteJson('/designations/$id');

  // --- MARKETING API METHODS ---
  Future<List<Map<String, dynamic>>> fetchCampaigns({Map<String, String>? query}) =>
      _list('/campaigns', query: query, softFail: true);

  Future<Map<String, dynamic>> createCampaign(Map<String, dynamic> body) =>
      client.postJson('/campaigns', body: body);

  Future<Map<String, dynamic>> updateCampaign(String id, Map<String, dynamic> body) =>
      client.putJson('/campaigns/$id', body: body);

  Future<void> deleteCampaign(String id) =>
      client.deleteJson('/campaigns/$id');

  Future<List<Map<String, dynamic>>> fetchSocialCalendar({Map<String, String>? query}) =>
      _list('/social-calendars', query: query, softFail: true);







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

  Future<List<Map<String, dynamic>>> fetchChatConversations(String employeeId) async {
    final res = await client.getJson(CrmPaths.chatConversations, query: {'employeeId': employeeId});
    return _asMapListFromKey(res, 'conversations');
  }

  Future<Map<String, dynamic>> createDirectChat({
    required String employeeId,
    required String peerId,
  }) async {
    final res = await client.postJson(CrmPaths.chatConversations, body: {
      'employeeId': employeeId,
      'peerId': peerId,
    });
    final conv = res['conversation'];
    if (conv is Map) return Map<String, dynamic>.from(conv);
    return res;
  }

  Future<ChatMessagesPage> fetchChatMessages({
    required String conversationId,
    required String employeeId,
    String day = 'today',
  }) async {
    final res = await client.getJson(
      CrmPaths.chatMessages(conversationId),
      query: {'employeeId': employeeId, 'day': day},
    );
    return ChatMessagesPage(
      messages: _asMapListFromKey(res, 'messages'),
      day: res['day']?.toString(),
      hasOlder: res['hasOlder'] == true,
    );
  }

  Future<Map<String, dynamic>> sendChatMessage({
    required String conversationId,
    required String employeeId,
    required String body,
    List<Map<String, dynamic>> mentions = const [],
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    final res = await client.postJson(CrmPaths.chatMessages(conversationId), body: {
      'employeeId': employeeId,
      'body': body,
      'mentions': mentions,
      'attachments': attachments,
    });
    final msg = res['message'];
    if (msg is Map) return Map<String, dynamic>.from(msg);
    return res;
  }

  Future<void> markChatRead({
    required String conversationId,
    required String employeeId,
  }) async {
    await client.patchJson(CrmPaths.chatRead(conversationId), body: {'employeeId': employeeId});
  }

  Future<List<Map<String, dynamic>>> searchChatEmployees(String search) async {
    final res = await client.getJson(
      CrmPaths.chatEmployees,
      query: search.trim().isEmpty ? null : {'search': search.trim()},
    );
    return _asMapListFromKey(res, 'employees');
  }

  Future<Map<String, dynamic>> voteChatPoll({
    required String messageId,
    required String employeeId,
    required int optionIndex,
  }) async {
    final res = await client.postJson(CrmPaths.chatVote(messageId), body: {
      'employeeId': employeeId,
      'optionIndex': optionIndex,
    });
    final msg = res['message'];
    if (msg is Map) return Map<String, dynamic>.from(msg);
    return res;
  }

  Future<Map<String, dynamic>> createChatPoll({
    required String conversationId,
    required String employeeId,
    required String question,
    required List<String> options,
    bool allowMultiple = false,
  }) async {
    final res = await client.postJson(CrmPaths.chatPolls(conversationId), body: {
      'employeeId': employeeId,
      'question': question,
      'options': options,
      'allowMultiple': allowMultiple,
    });
    final msg = res['message'];
    if (msg is Map) return Map<String, dynamic>.from(msg);
    return res;
  }


  Future<Map<String, dynamic>> fetchTravelTimeline({
    required String employeeId,
    required String date,
  }) =>
      client.getJson(CrmPaths.siteVisitsTravelTimeline, query: {
        'employeeId': employeeId,
        'date': date,
      });

  Future<List<Map<String, dynamic>>> fetchSiteVisits({
    required String assignedTo,
    required String from,
    required String to,
  }) async {
    final res = await client.getJson(CrmPaths.siteVisits, query: {
      'assignedTo': assignedTo,
      'from': from,
      'to': to,
    });
    return _asMapList(res);
  }

  Future<Map<String, dynamic>> startTravelJourney({
    required String employeeId,
    required String date,
    required double latitude,
    required double longitude,
    required String address,
  }) =>
      client.postJson(CrmPaths.siteVisitsStartJourney, body: {
        'employeeId': employeeId,
        'date': date,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
      });

  Future<Map<String, dynamic>> endTravelJourney({
    required String employeeId,
    required String date,
    required double latitude,
    required double longitude,
    required String address,
  }) =>
      client.postJson(CrmPaths.siteVisitsEndJourney, body: {
        'employeeId': employeeId,
        'date': date,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
      });

  Future<Map<String, dynamic>> allocateTravelExpense({
    required String employeeId,
    required String date,
  }) =>
      client.postJson(CrmPaths.siteVisitsAllocateExpense, body: {
        'employeeId': employeeId,
        'date': date,
      });

  Future<Map<String, dynamic>> checkInSiteVisit({
    required String visitId,
    required String employeeId,
    required double latitude,
    required double longitude,
    required String address,
  }) =>
      client.postJson(CrmPaths.siteVisitCheckIn(visitId), body: {
        'employeeId': employeeId,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
      });

  Future<Map<String, dynamic>> checkOutSiteVisit({
    required String visitId,
    required String employeeId,
    required double latitude,
    required double longitude,
    required String address,
  }) =>
      client.postJson(CrmPaths.siteVisitCheckOut(visitId), body: {
        'employeeId': employeeId,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
      });

  static List<Map<String, dynamic>> _asMapListFromKey(Map<String, dynamic> res, String key) {
    final raw = res[key] ?? res['data'] ?? res;
    if (raw is! List) return [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

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

  // --- COLLABORATORS API ---
  Future<List<Map<String, dynamic>>> getCollaborators({
    String? rateType,
    String? city,
    String? individualType,
  }) async {
    final query = <String, String>{};
    if (rateType != null && rateType.isNotEmpty) query['rateType'] = rateType;
    if (city != null && city.isNotEmpty) query['city'] = city;
    if (individualType != null && individualType.isNotEmpty) {
      query['individualType'] = individualType;
    }
    final res = await client.getJson('/collaborators', query: query);
    final data = res['data'] ?? res;
    if (data is List) {
      return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];

  }

  Future<Map<String, dynamic>> getCollaboratorById(String id) async {
    final res = await client.getJson('/collaborators/$id');
    return res;
  }

  Future<Map<String, dynamic>> createCollaborator(Map<String, dynamic> body) async {
    final res = await client.postJson('/collaborators', body: body);
    return res;
  }

  Future<Map<String, dynamic>> updateCollaborator(String id, Map<String, dynamic> body) async {
    final res = await client.putJson('/collaborators/$id', body: body);
    return res;
  }

  Future<void> deleteCollaborator(String id) async {
    await client.deleteJson('/collaborators/$id');
  }

}


