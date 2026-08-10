/// Client-side aggregates matching web `AdminDashboardView` useMemo.
class NamedCount {
  const NamedCount({required this.name, required this.value, this.color});

  final String name;
  final int value;
  final int? color;
}

class DayRevenue {
  const DayRevenue({required this.day, required this.revenue, required this.label});

  final String day;
  final double revenue;
  final String label;
}

class TopEmployee {
  const TopEmployee({
    required this.name,
    required this.designation,
    required this.count,
    required this.value,
  });

  final String name;
  final String designation;
  final int count;
  final double value;
}

class ActivityItem {
  const ActivityItem({
    required this.type,
    required this.title,
    required this.date,
  });

  final String type;
  final String title;
  final DateTime date;
}

class DashboardStats {
  const DashboardStats({
    required this.employeeCount,
    required this.clientCount,
    required this.projectCount,
    required this.leadCount,
    required this.taskCount,
    required this.revenue,
    required this.revenueGrowth,
    required this.employeeGrowth,
    required this.leadGrowth,
    required this.dealGrowth,
    required this.taskGrowth,
    required this.newLeadsThisMonth,
    required this.openDeals,
    required this.completedTasks,
    required this.activeProjects,
    required this.pendingInvoices,
    required this.pendingLeave,
    required this.revenueByDay,
    required this.weekRevenue,
    required this.weekAvg,
    required this.peakDay,
    required this.leadsBySource,
    required this.taskChart,
    required this.topEmployees,
    required this.activities,
    required this.projectGrowth,
    required this.clientGrowth,
  });

  final int employeeCount;
  final int clientCount;
  final int projectCount;
  final int leadCount;
  final int taskCount;
  final double revenue;
  final double revenueGrowth;
  final double employeeGrowth;
  final double leadGrowth;
  final double dealGrowth;
  final double taskGrowth;
  final int newLeadsThisMonth;
  final int openDeals;
  final int completedTasks;
  final int activeProjects;
  final int pendingInvoices;
  final int pendingLeave;
  final List<DayRevenue> revenueByDay;
  final double weekRevenue;
  final double weekAvg;
  final DayRevenue peakDay;
  final List<NamedCount> leadsBySource;
  final List<NamedCount> taskChart;
  final List<TopEmployee> topEmployees;
  final List<ActivityItem> activities;
  final double projectGrowth;
  final double clientGrowth;

  static DashboardStats fromLists({
    required List<Map<String, dynamic>> employees,
    required List<Map<String, dynamic>> clients,
    required List<Map<String, dynamic>> projects,
    required List<Map<String, dynamic>> leads,
    required List<Map<String, dynamic>> tasks,
    required List<Map<String, dynamic>> billings,
    required List<Map<String, dynamic>> leaves,
  }) {
    final revenue = billings.fold<double>(0, (s, b) => s + _amount(b));
    final revenueThisMonth = billings
        .where((b) => _isThisMonth(_paymentDate(b)))
        .fold<double>(0, (s, b) => s + _amount(b));
    final revenueLastMonth = billings
        .where((b) => _isLastMonth(_paymentDate(b)))
        .fold<double>(0, (s, b) => s + _amount(b));

    final newLeadsThisMonth = leads.where((l) => _isThisMonth(_date(l['createdAt']))).length;
    final newLeadsLastMonth = leads.where((l) => _isLastMonth(_date(l['createdAt']))).length;
    const openStatuses = ['Interested', 'Meeting Schedule', 'Call You After Sometime'];
    const dealMomStatuses = ['Interested', 'Meeting Schedule'];
    final openDeals = leads.where((l) => openStatuses.contains(l['status'])).length;
    final openDealsThisMonth = leads
        .where((l) =>
            dealMomStatuses.contains(l['status']) &&
            _isThisMonth(_date(l['updatedAt'] ?? l['createdAt'])))
        .length;
    final openDealsLastMonth = leads
        .where((l) =>
            dealMomStatuses.contains(l['status']) &&
            _isLastMonth(_date(l['updatedAt'] ?? l['createdAt'])))
        .length;

    final completed = tasks.where((t) => t['status'] == 'Completed').toList();
    final completedThisMonth = completed
        .where((t) => _isThisMonth(_date(t['completedAt'] ?? t['updatedAt'])))
        .length;
    final completedLastMonth = completed
        .where((t) => _isLastMonth(_date(t['completedAt'] ?? t['updatedAt'])))
        .length;

    final employeesThisMonth =
        employees.where((e) => _isThisMonth(_date(e['createdAt'] ?? e['dateOfJoining']))).length;
    final employeesLastMonth =
        employees.where((e) => _isLastMonth(_date(e['createdAt'] ?? e['dateOfJoining']))).length;

    final activeProjects = projects.where((p) => p['status'] == 'In Progress').length;
    final pendingInvoices = billings.where((b) {
      final a = _amount(b);
      return a == 0;
    }).length;
    final pendingLeave = leaves.where((l) => l['status'] == 'Pending').length;

    final weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final revenueByDay = <DayRevenue>[];
    for (var i = 6; i >= 0; i--) {
      final now = DateTime.now();
      final d = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final next = d.add(const Duration(days: 1));
      final dayTotal = billings.fold<double>(0, (s, b) {
        final pd = _paymentDate(b);
        if (pd == null) return s;
        if (!pd.isBefore(d) && pd.isBefore(next)) return s + _amount(b);
        return s;
      });
      revenueByDay.add(DayRevenue(
        day: weekdayLabels[d.weekday - 1],
        revenue: dayTotal,
        label: '${d.day} ${_monthShort(d.month)} ${d.year}',
      ));
    }

    final weekRevenue = revenueByDay.fold<double>(0, (s, d) => s + d.revenue);
    final weekAvg = (weekRevenue / revenueByDay.length).roundToDouble();
    var peakDay = revenueByDay.isEmpty
        ? const DayRevenue(day: '—', revenue: 0, label: '')
        : revenueByDay.first;
    for (final d in revenueByDay) {
      if (d.revenue > peakDay.revenue) peakDay = d;
    }

    final sourceMap = <String, int>{};
    for (final l in leads) {
      final src = ((l['leadSource'] ?? 'Other').toString().trim().isEmpty)
          ? 'Other'
          : (l['leadSource'] ?? 'Other').toString().trim();
      sourceMap[src] = (sourceMap[src] ?? 0) + 1;
    }
    final chartColors = const [
      0xFF2563EB,
      0xFF7C3AED,
      0xFF0891B2,
      0xFFD97706,
      0xFF059669,
      0xFFDB2777,
      0xFF4F46E5,
    ];
    final leadsBySource = sourceMap.entries
        .map((e) => NamedCount(name: e.key, value: e.value))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (var i = 0; i < leadsBySource.length; i++) {
      leadsBySource[i] = NamedCount(
        name: leadsBySource[i].name,
        value: leadsBySource[i].value,
        color: chartColors[i % chartColors.length],
      );
    }

    const taskColors = {
      'Completed': 0xFF059669,
      'In Progress': 0xFF2563EB,
      'Pending': 0xFFD97706,
      'Cancelled': 0xFF94A3B8,
    };
    final taskStatusMap = {
      'Completed': 0,
      'In Progress': 0,
      'Pending': 0,
      'Cancelled': 0,
    };
    for (final t in tasks) {
      final status = t['status']?.toString() ?? 'Pending';
      final key = taskStatusMap.containsKey(status) ? status : 'Pending';
      taskStatusMap[key] = (taskStatusMap[key] ?? 0) + 1;
    }
    final taskChart = taskStatusMap.entries
        .where((e) => e.value > 0)
        .map((e) => NamedCount(
              name: e.key,
              value: e.value,
              color: taskColors[e.key] ?? 0xFF94A3B8,
            ))
        .toList();

    final leadCountByEmployee = <String, _LeadAgg>{};
    for (final l in leads) {
      final gen = l['generatedBy'];
      String? key;
      Map<String, dynamic>? emp;
      if (gen is Map) {
        key = (gen['_id'] ?? gen['id'])?.toString();
        emp = Map<String, dynamic>.from(gen);
      } else if (gen != null) {
        key = gen.toString();
        for (final e in employees) {
          if (e['_id']?.toString() == key) {
            emp = e;
            break;
          }
        }
      }
      if (key == null || key.isEmpty) continue;
      final existing = leadCountByEmployee.putIfAbsent(
        key,
        () => _LeadAgg(employee: emp, count: 0),
      );
      existing.count += 1;
      if (existing.employee == null && emp != null) existing.employee = emp;
    }
    final topEmployees = leadCountByEmployee.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    final top5 = topEmployees.take(5).map((item) {
      final e = item.employee;
      final designation = () {
        final d = e?['designation'];
        if (d is Map) return (d['title'] ?? d['name'] ?? e?['department'] ?? '—').toString();
        return (e?['department'] ?? '—').toString();
      }();
      return TopEmployee(
        name: (e?['name'] ?? 'Employee').toString(),
        designation: designation,
        count: item.count,
        value: item.count * 50000.0,
      );
    }).toList();

    final activities = <ActivityItem>[
      ...projects.map((p) => ActivityItem(
            type: 'Project',
            title: 'Project "${p['projectName'] ?? ''}" updated',
            date: _date(p['updatedAt'] ?? p['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
          )),
      ...clients.map((c) => ActivityItem(
            type: 'Client',
            title: 'Client "${c['clientName'] ?? ''}" added',
            date: _date(c['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
          )),
      ...employees.map((e) => ActivityItem(
            type: 'Employee',
            title: 'Employee "${e['name'] ?? ''}" joined',
            date: _date(e['createdAt'] ?? e['dateOfJoining']) ??
                DateTime.fromMillisecondsSinceEpoch(0),
          )),
      ...leads.map((l) => ActivityItem(
            type: 'Lead',
            title: 'New lead "${l['businessName'] ?? l['name'] ?? ''}"',
            date: _date(l['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
          )),
      ...completed.map((t) => ActivityItem(
            type: 'Task',
            title: 'Task completed: ${t['title'] ?? ''}',
            date: _date(t['completedAt'] ?? t['updatedAt']) ??
                DateTime.fromMillisecondsSinceEpoch(0),
          )),
    ].where((a) => a.date.millisecondsSinceEpoch > 0).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final projectGrowth = _growthPct(
      projects.where((p) => _isThisMonth(_date(p['createdAt']))).length,
      projects.where((p) => _isLastMonth(_date(p['createdAt']))).length,
    );
    final clientGrowth = _growthPct(
      clients.where((c) => _isThisMonth(_date(c['createdAt']))).length,
      clients.where((c) => _isLastMonth(_date(c['createdAt']))).length,
    );

    return DashboardStats(
      employeeCount: employees.length,
      clientCount: clients.length,
      projectCount: projects.length,
      leadCount: leads.length,
      taskCount: tasks.length,
      revenue: revenue,
      revenueGrowth: _growthPct(revenueThisMonth, revenueLastMonth),
      employeeGrowth: _growthPct(employeesThisMonth.toDouble(), employeesLastMonth.toDouble()),
      leadGrowth: _growthPct(newLeadsThisMonth.toDouble(), newLeadsLastMonth.toDouble()),
      dealGrowth: _growthPct(openDealsThisMonth.toDouble(), openDealsLastMonth.toDouble()),
      taskGrowth: _growthPct(completedThisMonth.toDouble(), completedLastMonth.toDouble()),
      newLeadsThisMonth: newLeadsThisMonth,
      openDeals: openDeals,
      completedTasks: completed.length,
      activeProjects: activeProjects,
      pendingInvoices: pendingInvoices,
      pendingLeave: pendingLeave,
      revenueByDay: revenueByDay,
      weekRevenue: weekRevenue,
      weekAvg: weekAvg,
      peakDay: peakDay,
      leadsBySource: leadsBySource,
      taskChart: taskChart,
      topEmployees: top5,
      activities: activities.take(8).toList(),
      projectGrowth: projectGrowth,
      clientGrowth: clientGrowth,
    );
  }

  static double _amount(Map<String, dynamic> b) {
    final details = b['paymentDetails'];
    if (details is Map) return (num.tryParse('${details['amount']}') ?? 0).toDouble();
    return 0;
  }

  static DateTime? _paymentDate(Map<String, dynamic> b) {
    final details = b['paymentDetails'];
    if (details is Map && details['paymentDate'] != null) {
      return _date(details['paymentDate']);
    }
    return _date(b['createdAt']);
  }

  static DateTime? _date(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  static bool _isThisMonth(DateTime? d) {
    if (d == null) return false;
    final now = DateTime.now();
    return d.month == now.month && d.year == now.year;
  }

  static bool _isLastMonth(DateTime? d) {
    if (d == null) return false;
    final now = DateTime.now();
    final lm = DateTime(now.year, now.month - 1, 1);
    return d.month == lm.month && d.year == lm.year;
  }

  static double _growthPct(num current, num previous) {
    if (previous == 0) return current > 0 ? 100 : 0;
    return (((current - previous) / previous) * 1000).round() / 10;
  }

  static String _monthShort(int m) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return names[m - 1];
  }
}

class _LeadAgg {
  _LeadAgg({this.employee, required this.count});
  Map<String, dynamic>? employee;
  int count;
}
