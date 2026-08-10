/// Client-side aggregates for web `EmployeeDashboardView`.
class EmployeePipelineStage {
  const EmployeePipelineStage({
    required this.label,
    required this.count,
    required this.value,
    required this.color,
  });

  final String label;
  final int count;
  final double value;
  final int color;
}

class ScheduleItem {
  const ScheduleItem({
    required this.id,
    required this.time,
    required this.title,
    required this.subtitle,
    required this.kind,
  });

  final String id;
  final DateTime? time;
  final String title;
  final String subtitle;
  final String kind;
}

class EmployeeDashboardStats {
  const EmployeeDashboardStats({
    required this.tasks,
    required this.leads,
    required this.announcements,
    required this.todaysTasks,
    required this.pastIncompleteTasks,
    required this.completedThisMonth,
    required this.openDeals,
    required this.meetingsToday,
    required this.followUps,
    required this.missedFollowUps,
    required this.totalIncentiveEarned,
    required this.dealsClosed,
    required this.performancePct,
    required this.avgRating,
    required this.ratedTasks,
    required this.pipelineStages,
    required this.pipelineTotalValue,
    required this.todaySchedule,
    required this.recentLeads,
    required this.pendingTasksCount,
    required this.recentAnnouncements,
  });

  final int tasks;
  final int leads;
  final int announcements;
  final int todaysTasks;
  final int pastIncompleteTasks;
  final int completedThisMonth;
  final int openDeals;
  final int meetingsToday;
  final int followUps;
  final int missedFollowUps;
  final double totalIncentiveEarned;
  final int dealsClosed;
  final double performancePct;
  final double? avgRating;
  final List<Map<String, dynamic>> ratedTasks;
  final List<EmployeePipelineStage> pipelineStages;
  final double pipelineTotalValue;
  final List<ScheduleItem> todaySchedule;
  final List<Map<String, dynamic>> recentLeads;
  final int pendingTasksCount;
  final List<Map<String, dynamic>> recentAnnouncements;

  static const _closedLeadStatuses = {
    'Not Interested',
    'Booking Done',
    'Token Done',
    'Booking Token',
    'Incentive Earned',
  };

  static const _openDealStatuses = {
    'Interested',
    'Meeting Schedule',
    'Call You After Sometime',
    'Zoom Meeting',
    'Site Visit',
  };

  static EmployeeDashboardStats fromLists({
    required List<Map<String, dynamic>> tasks,
    required List<Map<String, dynamic>> leads,
    required List<Map<String, dynamic>> announcements,
    DateTime? now,
  }) {
    final ref = now ?? DateTime.now();
    final pendingTasks = tasks.where((t) => _isIncompleteTask(t)).toList();
    final todaysTasks = pendingTasks.where((t) => _isSameDay(t['dueDate'], ref)).length;
    final pastIncompleteTasks = pendingTasks.where((t) => _isPastDay(t['dueDate'], ref)).length;
    final completedTasks = tasks.where((t) => t['status'] == 'Completed').toList();
    final completedThisMonth = completedTasks.where((t) => _isThisMonth(t['completedAt'] ?? t['updatedAt'], ref)).length;

    final openDeals = leads.where((l) => _openDealStatuses.contains(l['status']?.toString())).length;
    final meetingsToday = leads.where((l) {
      final status = l['status']?.toString();
      if (status != 'Meeting Schedule' && status != 'Zoom Meeting') return false;
      return _isSameDay(l['meetingTime'], ref);
    }).length;

    final followUps = leads.where((l) {
      if (_closedLeadStatuses.contains(l['status']?.toString())) return false;
      final latest = _latestFollowUpDate(l);
      if (latest != null && !_isPastDay(latest, ref)) return true;
      return l['status'] == 'Call You After Sometime';
    }).length;

    final missedFollowUps = leads.where((l) {
      if (_closedLeadStatuses.contains(l['status']?.toString())) return false;
      final latest = _latestFollowUpDate(l);
      return latest != null && _isPastDay(latest, ref);
    }).length;

    final totalIncentiveEarned = leads.fold<double>(0, (s, l) => s + (num.tryParse('${l['incentiveAmount']}') ?? 0).toDouble());

    final dealsClosed = leads.where((l) {
      final status = l['status']?.toString() ?? '';
      return ['Booking Done', 'Token Done', 'Booking Token', 'Incentive Earned'].contains(status) ||
          l['meetingInfoSent'] == true;
    }).length;

    final pipelineStages = _buildPipelineStages(leads);
    final pipelineTotalValue = pipelineStages.fold<double>(0, (s, st) => s + st.value);

    final schedule = <ScheduleItem>[
      ...leads.where((l) {
        final status = l['status']?.toString();
        if (status != 'Meeting Schedule' && status != 'Zoom Meeting') return false;
        return _isSameDay(l['meetingTime'], ref);
      }).map((m) => ScheduleItem(
            id: '${m['_id']}',
            time: _parseDate(m['meetingTime']),
            title: (m['businessName'] ?? m['name'] ?? 'Meeting').toString(),
            subtitle: '${m['meetingType'] ?? 'Meeting'} · ${m['meetingPersonName'] ?? 'Client'}',
            kind: 'meeting',
          )),
      ...tasks.where((t) => _isSameDay(t['dueDate'], ref) && t['status'] != 'Completed').map((t) => ScheduleItem(
            id: '${t['_id']}',
            time: _parseDate(t['dueDate']),
            title: (t['title'] ?? 'Task').toString(),
            subtitle: _projectName(t),
            kind: 'task',
          )),
    ]..sort((a, b) {
        final ta = a.time ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tb = b.time ?? DateTime.fromMillisecondsSinceEpoch(0);
        return ta.compareTo(tb);
      });

    final recentLeads = [...leads]..sort((a, b) {
        final da = _parseDate(b['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final db = _parseDate(a['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return da.compareTo(db);
      });

    final ratedTasks = tasks.where((t) {
      if (!_isRealTask(t)) return false;
      final rating = t['rating'];
      if (rating is Map) return rating['score'] != null;
      return false;
    }).toList()
      ..sort((a, b) {
        final ra = a['rating'] is Map ? a['rating']['ratedAt'] ?? a['updatedAt'] : a['updatedAt'];
        final rb = b['rating'] is Map ? b['rating']['ratedAt'] ?? b['updatedAt'] : b['updatedAt'];
        return (_parseDate(rb) ?? DateTime(0)).compareTo(_parseDate(ra) ?? DateTime(0));
      });

    final scores = ratedTasks
        .map((t) => num.tryParse('${(t['rating'] as Map)['score']}') ?? 0)
        .where((s) => s > 0)
        .toList();
    final avgRating = scores.isEmpty
        ? null
        : ((scores.fold<double>(0, (a, b) => a + b.toDouble()) / scores.length) * 10).round() / 10;

    final monthlyTarget = pendingTasks.length + completedThisMonth;
    final performancePct = monthlyTarget == 0 ? 0.0 : (completedThisMonth / monthlyTarget) * 100;

    return EmployeeDashboardStats(
      tasks: tasks.length,
      leads: leads.length,
      announcements: announcements.length,
      todaysTasks: todaysTasks,
      pastIncompleteTasks: pastIncompleteTasks,
      completedThisMonth: completedThisMonth,
      openDeals: openDeals,
      meetingsToday: meetingsToday,
      followUps: followUps,
      missedFollowUps: missedFollowUps,
      totalIncentiveEarned: totalIncentiveEarned,
      dealsClosed: dealsClosed,
      performancePct: performancePct,
      avgRating: avgRating,
      ratedTasks: ratedTasks,
      pipelineStages: pipelineStages,
      pipelineTotalValue: pipelineTotalValue,
      todaySchedule: schedule,
      recentLeads: recentLeads.take(5).toList(),
      pendingTasksCount: pendingTasks.length,
      recentAnnouncements: announcements.take(5).toList(),
    );
  }

  static List<EmployeePipelineStage> _buildPipelineStages(List<Map<String, dynamic>> leads) {
    const configs = [
      ('Leads', 52000, 0xFF3B82F6),
      ('Qualified', 65000, 0xFF8B5CF6),
      ('Proposal', 60000, 0xFF14B8A6),
      ('Negotiation', 52500, 0xFFF59E0B),
      ('Closed Won', 60000, 0xFF10B981),
    ];
    final counts = [
      leads.length,
      leads.where((l) => l['status'] == 'Interested').length,
      leads.where((l) => l['status'] == 'Meeting Schedule').length,
      leads.where((l) => l['status'] == 'Call You After Sometime').length,
      leads.where((l) => l['meetingInfoSent'] == true).length,
    ];
    return List.generate(configs.length, (i) {
      final cfg = configs[i];
      return EmployeePipelineStage(
        label: cfg.$1,
        count: counts[i],
        value: counts[i] * cfg.$2.toDouble(),
        color: cfg.$3,
      );
    });
  }

  static bool _isIncompleteTask(Map<String, dynamic> t) {
    const open = {'Pending', 'In Progress', 'Paused'};
    return open.contains(t['status']?.toString());
  }

  static bool _isRealTask(Map<String, dynamic> t) {
    final id = t['_id']?.toString() ?? '';
    return id.isNotEmpty && !id.startsWith('social-media-');
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool _isSameDay(dynamic a, DateTime ref) {
    final d = _parseDate(a);
    if (d == null) return false;
    return d.year == ref.year && d.month == ref.month && d.day == ref.day;
  }

  static bool _isPastDay(dynamic a, DateTime ref) {
    final d = _parseDate(a);
    if (d == null) return false;
    return _startOfDay(d).isBefore(_startOfDay(ref));
  }

  static bool _isThisMonth(dynamic a, DateTime ref) {
    final d = _parseDate(a);
    if (d == null) return false;
    return d.month == ref.month && d.year == ref.year;
  }

  static DateTime? _latestFollowUpDate(Map<String, dynamic> lead) {
    final fus = lead['followUps'];
    if (fus is! List) return null;
    DateTime? latest;
    for (final fu in fus) {
      if (fu is! Map) continue;
      final d = _parseDate(fu['date']);
      if (d == null) continue;
      if (latest == null || d.isAfter(latest)) latest = d;
    }
    return latest;
  }

  static String _projectName(Map<String, dynamic> task) {
    final p = task['project'];
    if (p is Map) return (p['projectName'] ?? p['name'] ?? 'Project').toString();
    return 'General';
  }
}
