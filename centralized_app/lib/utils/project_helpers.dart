import 'package:flutter/material.dart';

/// Project helpers mirroring web `projectUtils.js`.
class ProjectHelpers {
  ProjectHelpers._();

  static const statusOptions = ['All', 'Not Started', 'In Progress', 'On Hold', 'Completed', 'Cancelled'];

  static String clientName(Map<String, dynamic> project) {
    final client = project['client'];
    if (client is Map) return (client['clientName'] ?? client['name'] ?? '—').toString();
    return '—';
  }

  static String? clientId(Map<String, dynamic> project) {
    final client = project['client'];
    if (client is Map) return '${client['_id'] ?? ''}';
    if (client != null) return client.toString();
    return null;
  }

  static String projectName(Map<String, dynamic> project) =>
      (project['projectName'] ?? project['name'] ?? 'Project').toString();

  static String projectCode(Map<String, dynamic> project, int index) {
    final created = DateTime.tryParse('${project['createdAt']}');
    final year = created?.year ?? DateTime.now().year;
    return 'PRJ-$year-${(index + 1).toString().padLeft(3, '0')}';
  }

  static List<Map<String, dynamic>> teamList(Map<String, dynamic> project) {
    final members = <Map<String, dynamic>>[];
    final seen = <String>{};
    void add(dynamic person) {
      if (person == null) return;
      if (person is Map) {
        final id = '${person['_id'] ?? ''}';
        if (id.isEmpty || seen.contains(id)) return;
        seen.add(id);
        members.add(Map<String, dynamic>.from(person));
      }
    }
    add(project['projectManager']);
    final team = project['teamMembers'];
    if (team is List) {
      for (final m in team) {
        add(m);
      }
    }
    return members;
  }

  static String formatInr(dynamic amount) {
    if (amount == null || '$amount'.isEmpty) return '—';
    final v = num.tryParse('$amount') ?? 0;
    final s = v.round().toString();
    if (s.length <= 3) return '₹ $s';
    final last3 = s.substring(s.length - 3);
    final rest = s.substring(0, s.length - 3);
    final buf = StringBuffer('₹ ');
    for (var i = 0; i < rest.length; i++) {
      if (i > 0 && (rest.length - i) % 2 == 0) buf.write(',');
      buf.write(rest[i]);
    }
    buf.write(',$last3');
    return buf.toString();
  }

  static String formatDeadline(dynamic date) {
    if (date == null) return '—';
    final d = DateTime.tryParse(date.toString());
    if (d == null) return '—';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }

  static Color deadlineColor(dynamic date, String? status) {
    if (date == null || status == 'Completed' || status == 'Cancelled') return const Color(0xFF475569);
    final d = DateTime.tryParse(date.toString());
    if (d == null) return const Color(0xFF475569);
    final today = DateTime.now();
    final diff = DateTime(d.year, d.month, d.day).difference(DateTime(today.year, today.month, today.day)).inDays;
    if (diff < 0) return const Color(0xFFDC2626);
    if (diff <= 7) return const Color(0xFFEA580C);
    return const Color(0xFF059669);
  }

  static (Color bg, Color fg) statusColors(String? status) {
    switch (status) {
      case 'In Progress':
        return (const Color(0xFFDBEAFE), const Color(0xFF1D4ED8));
      case 'Completed':
        return (const Color(0xFFD1FAE5), const Color(0xFF047857));
      case 'On Hold':
        return (const Color(0xFFFFEDD5), const Color(0xFFC2410C));
      case 'Cancelled':
        return (const Color(0xFFFEE2E2), const Color(0xFFB91C1C));
      default:
        return (const Color(0xFFF1F5F9), const Color(0xFF475569));
    }
  }

  static Color statusChartColor(String status) {
    switch (status) {
      case 'In Progress':
        return const Color(0xFF3B82F6);
      case 'Completed':
        return const Color(0xFF10B981);
      case 'On Hold':
        return const Color(0xFFF59E0B);
      case 'Cancelled':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  static ProjectStats computeStats(List<Map<String, dynamic>> projects) {
    final total = projects.length;
    int count(String s) => projects.where((p) => p['status'] == s).length;
    final now = DateTime.now();
    final thisMonth = projects.where((p) {
      final d = DateTime.tryParse('${p['createdAt']}');
      return d != null && d.month == now.month && d.year == now.year;
    }).length;
    final lastMonthDate = DateTime(now.year, now.month - 1);
    final lastMonth = projects.where((p) {
      final d = DateTime.tryParse('${p['createdAt']}');
      return d != null && d.month == lastMonthDate.month && d.year == lastMonthDate.year;
    }).length;
    final growth = lastMonth == 0 ? (thisMonth > 0 ? 100 : 0) : (((thisMonth - lastMonth) / lastMonth) * 100).round();
    return ProjectStats(
      total: total,
      inProgress: count('In Progress'),
      completed: count('Completed'),
      onHold: count('On Hold'),
      cancelled: count('Cancelled'),
      growth: growth,
    );
  }

  static List<({String name, int value, Color color})> statusChartData(List<Map<String, dynamic>> projects) {
    final counts = <String, int>{};
    for (final p in projects) {
      final s = (p['status'] ?? 'Not Started').toString();
      counts[s] = (counts[s] ?? 0) + 1;
    }
    return counts.entries
        .map((e) => (name: e.key, value: e.value, color: statusChartColor(e.key)))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
  }

  static List<Map<String, dynamic>> upcomingDeadlines(List<Map<String, dynamic>> projects, {int limit = 4}) {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final list = projects.where((p) {
      final d = DateTime.tryParse('${p['deadline'] ?? p['endDate']}');
      if (d == null) return false;
      if (p['status'] == 'Completed' || p['status'] == 'Cancelled') return false;
      return !DateTime(d.year, d.month, d.day).isBefore(today);
    }).toList()
      ..sort((a, b) {
        final da = DateTime.tryParse('${a['deadline'] ?? a['endDate']}') ?? DateTime(2100);
        final db = DateTime.tryParse('${b['deadline'] ?? b['endDate']}') ?? DateTime(2100);
        return da.compareTo(db);
      });
    return list.take(limit).toList();
  }

  static List<({String id, String name, int count})> topClients(List<Map<String, dynamic>> projects, {int limit = 5}) {
    final map = <String, ({String id, String name, int count})>{};
    for (final p in projects) {
      final id = clientId(p);
      final name = clientName(p);
      if (id == null || id.isEmpty || name == '—') continue;
      final prev = map[id];
      map[id] = (id: id, name: name, count: (prev?.count ?? 0) + 1);
    }
    final list = map.values.toList()..sort((a, b) => b.count.compareTo(a.count));
    return list.take(limit).toList();
  }
}

class ProjectStats {
  const ProjectStats({
    required this.total,
    required this.inProgress,
    required this.completed,
    required this.onHold,
    required this.cancelled,
    required this.growth,
  });

  final int total;
  final int inProgress;
  final int completed;
  final int onHold;
  final int cancelled;
  final int growth;

  int pct(int n) => total == 0 ? 0 : ((n / total) * 100).round();
}
