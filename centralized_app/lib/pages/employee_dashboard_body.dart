import 'package:flutter/material.dart';

import '../auth/auth_session.dart';
import '../auth/role_access.dart';
import '../dashboard/employee_dashboard_stats.dart';
import '../navigation/app_nav.dart';

/// Compact employee dashboard matching web `EmployeeDashboardView`.
class EmployeeDashboardBody extends StatelessWidget {
  const EmployeeDashboardBody({
    super.key,
    required this.stats,
    required this.firstName,
    required this.session,
  });

  final EmployeeDashboardStats stats;
  final String firstName;
  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    final designation = RoleAccess.designationTitle(session.user ?? {});
    final width = MediaQuery.sizeOf(context).width;
    final cardW = (width - 26) / 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back, ${firstName.isEmpty ? 'there' : firstName}!',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    "Here's what's happening with your work today.",
                    style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                  ),
                  if (designation.isNotEmpty)
                    Text(designation, style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(employeeWeekRangeLabel(), style: const TextStyle(fontSize: 9, color: Color(0xFF64748B))),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _EmpKpiCard(
              width: cardW,
              title: "Today's Tasks",
              value: '${stats.todaysTasks}',
              subtitle: 'Due today',
              accent: const Color(0xFF2563EB),
              onTap: () => AppNavScope.navigate(context, '/my-tasks'),
            ),
            _EmpKpiCard(
              width: cardW,
              title: 'Past Tasks',
              value: '${stats.pastIncompleteTasks}',
              subtitle: 'Not completed',
              accent: const Color(0xFFDC2626),
              onTap: () => AppNavScope.navigate(context, '/my-tasks'),
            ),
            _EmpKpiCard(
              width: cardW,
              title: 'Tasks Completed',
              value: '${stats.completedThisMonth}',
              subtitle: 'This month',
              accent: const Color(0xFF059669),
              onTap: () => AppNavScope.navigate(context, '/my-tasks'),
            ),
            _EmpKpiCard(
              width: cardW,
              title: 'My Leads',
              value: '${stats.leads}',
              subtitle: 'Total leads',
              accent: const Color(0xFF7C3AED),
              onTap: () => AppNavScope.navigate(context, '/lead-management'),
            ),
            _EmpKpiCard(
              width: cardW,
              title: 'Open Deals',
              value: '${stats.openDeals}',
              subtitle: 'In pipeline',
              accent: const Color(0xFFEA580C),
              onTap: () => AppNavScope.navigate(context, '/lead-management'),
            ),
            _EmpKpiCard(
              width: cardW,
              title: 'Meetings Today',
              value: '${stats.meetingsToday}',
              subtitle: 'Scheduled',
              accent: const Color(0xFF0891B2),
              onTap: () => AppNavScope.navigate(context, '/lead-management'),
            ),
            _EmpKpiCard(
              width: cardW,
              title: 'Follow-ups',
              value: '${stats.followUps}',
              subtitle: 'Upcoming',
              accent: const Color(0xFF4F46E5),
              onTap: () => AppNavScope.navigate(context, '/lead-management'),
            ),
            _EmpKpiCard(
              width: cardW,
              title: 'Missed Follow-ups',
              value: '${stats.missedFollowUps}',
              subtitle: 'Past due',
              accent: const Color(0xFFE11D48),
              onTap: () => AppNavScope.navigate(context, '/lead-management'),
            ),
            _EmpKpiCard(
              width: cardW,
              title: 'Total Incentive',
              value: formatInr(stats.totalIncentiveEarned),
              subtitle: 'From bookings',
              accent: const Color(0xFF10B981),
              onTap: () => AppNavScope.navigate(context, '/lead-management'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _EmpPanel(
          title: 'My Performance',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PerformanceRing(percent: stats.performancePct),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    _perfRow('Leads Assigned', '${stats.leads}'),
                    _perfRow('Deals Closed', '${stats.dealsClosed}'),
                    _perfRow('Tasks Done (Month)', '${stats.completedThisMonth}'),
                    _perfRow('Pending Tasks', '${stats.pendingTasksCount}'),
                    _perfRow('Avg Task Rating', stats.avgRating != null ? '${stats.avgRating}/5' : '—'),
                    _perfRow('Rated Tasks', '${stats.ratedTasks.length}'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _EmpPanel(
          title: 'My Sales Pipeline',
          actionLabel: 'View Pipeline',
          onAction: () => AppNavScope.navigate(context, '/lead-management'),
          child: Column(
            children: [
              Text(
                'Total pipeline value: ${formatInr(stats.pipelineTotalValue)}',
                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 8),
              for (final stage in stats.pipelineStages)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 72,
                        child: Text(stage.label, style: const TextStyle(fontSize: 10, color: Color(0xFF475569))),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: stats.pipelineStages.first.count == 0
                                ? 0
                                : stage.count / stats.pipelineStages.first.count,
                            minHeight: 8,
                            backgroundColor: const Color(0xFFF1F5F9),
                            color: Color(stage.color),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('${stage.count}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _EmpPanel(
          title: "Today's Schedule",
          actionLabel: 'My Tasks',
          onAction: () => AppNavScope.navigate(context, '/my-tasks'),
          child: stats.todaySchedule.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text('No meetings or tasks scheduled for today', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  ),
                )
              : Column(
                  children: stats.todaySchedule.map((item) {
                    final color = item.kind == 'meeting' ? const Color(0xFF2563EB) : const Color(0xFF7C3AED);
                    return InkWell(
                      onTap: () => AppNavScope.navigate(context, item.kind == 'meeting' ? '/lead-management' : '/my-tasks'),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(top: 4),
                              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatTime(item.time),
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                                  ),
                                  Text(item.title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                  Text(item.subtitle, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 8),
        _EmpPanel(
          title: 'Recent Leads',
          actionLabel: 'View All',
          onAction: () => AppNavScope.navigate(context, '/lead-management'),
          child: stats.recentLeads.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: Text('No leads yet', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
                )
              : Column(
                  children: stats.recentLeads.map((lead) {
                    final name = (lead['businessName'] ?? lead['name'] ?? 'Lead').toString();
                    final initials = name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();
                    return InkWell(
                      onTap: () => AppNavScope.navigate(context, '/lead-management'),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: const Color(0xFFDBEAFE),
                              child: Text(initials, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8))),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                                  Text(
                                    (lead['businessType'] ?? lead['city'] ?? 'Lead').toString(),
                                    style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _LeadStatusChip(status: lead['status']?.toString()),
                                Text(_fmtDate(lead['createdAt']), style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 8),
        _EmpPanel(
          title: 'Task Ratings',
          actionLabel: 'My Tasks',
          onAction: () => AppNavScope.navigate(context, '/my-tasks'),
          child: stats.ratedTasks.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      'No task ratings yet. Complete tasks to receive feedback.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Column(
                  children: stats.ratedTasks.take(6).map((task) {
                    final rating = task['rating'] is Map ? task['rating'] as Map : null;
                    final score = num.tryParse('${rating?['score']}') ?? 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  (task['title'] ?? 'Task').toString(),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              _StarDisplay(score: score.toDouble()),
                            ],
                          ),
                          if (rating?['comments'] != null && '${rating!['comments']}'.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '"${rating['comments']}"',
                                style: const TextStyle(fontSize: 10, color: Color(0xFF475569)),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
        if (stats.recentAnnouncements.isNotEmpty) ...[
          const SizedBox(height: 8),
          _EmpPanel(
            title: 'Announcements',
            actionLabel: 'View All',
            onAction: () => AppNavScope.navigate(context, '/module/announcements'),
            child: Column(
              children: stats.recentAnnouncements.map((a) {
                final priority = (a['priority'] ?? 'normal').toString();
                final icon = priority == 'urgent' ? '🚨' : priority == 'high' ? '📢' : 'ℹ️';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(icon, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (a['title'] ?? 'Announcement').toString(),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            if (a['message'] != null || a['content'] != null)
                              Text(
                                (a['message'] ?? a['content']).toString(),
                                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _perfRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)))),
          Text(value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _EmpKpiCard extends StatelessWidget {
  const _EmpKpiCard({
    required this.width,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accent,
    this.onTap,
  });

  final double width;
  final String title;
  final String value;
  final String subtitle;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 3,
                  width: 28,
                  decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 6),
                Text(title, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                Text(subtitle, style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmpPanel extends StatelessWidget {
  const _EmpPanel({
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            child: Row(
              children: [
                Expanded(child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                if (actionLabel != null && onAction != null)
                  GestureDetector(
                    onTap: onAction,
                    child: Text(actionLabel!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          Padding(padding: const EdgeInsets.all(10), child: child),
        ],
      ),
    );
  }
}

class _PerformanceRing extends StatelessWidget {
  const _PerformanceRing({required this.percent});
  final double percent;

  @override
  Widget build(BuildContext context) {
    final p = (percent / 100).clamp(0.0, 1.0);
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(
              value: p,
              strokeWidth: 6,
              backgroundColor: const Color(0xFFF1F5F9),
              color: const Color(0xFF2563EB),
            ),
          ),
          Text('${percent.round()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _StarDisplay extends StatelessWidget {
  const _StarDisplay({required this.score});
  final double score;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${score.toStringAsFixed(score == score.roundToDouble() ? 0 : 1)}/5 ★',
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFD97706)),
    );
  }
}

class _LeadStatusChip extends StatelessWidget {
  const _LeadStatusChip({this.status});
  final String? status;

  @override
  Widget build(BuildContext context) {
    final label = _leadStatusLabel(status);
    final (bg, fg) = _leadStatusColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

String _leadStatusLabel(String? status) {
  if (status == 'Call not Received') return 'New';
  if (status == 'Call You After Sometime') return 'Follow-up';
  if (status == 'Meeting Schedule') return 'Meeting';
  if (status == 'Zoom Meeting') return 'Zoom';
  return status ?? 'Lead';
}

(Color, Color) _leadStatusColors(String? status) {
  switch (status) {
    case 'Interested':
      return (const Color(0xFFFFEDD5), const Color(0xFFC2410C));
    case 'Meeting Schedule':
      return (const Color(0xFFDBEAFE), const Color(0xFF1D4ED8));
    case 'Site Visit':
      return (const Color(0xFFCFFAFE), const Color(0xFF0E7490));
    case 'Zoom Meeting':
      return (const Color(0xFFEDE9FE), const Color(0xFF6D28D9));
    case 'Booking Done':
    case 'Token Done':
    case 'Incentive Earned':
      return (const Color(0xFFD1FAE5), const Color(0xFF047857));
    case 'Not Interested':
      return (const Color(0xFFF1F5F9), const Color(0xFF475569));
    default:
      return (const Color(0xFFF3E8FF), const Color(0xFF7C3AED));
  }
}

String formatInr(num amount) {
  final v = amount.round();
  final s = v.toString();
  if (s.length <= 3) return '₹$s';
  final last3 = s.substring(s.length - 3);
  final rest = s.substring(0, s.length - 3);
  final buf = StringBuffer('₹');
  for (var i = 0; i < rest.length; i++) {
    if (i > 0 && (rest.length - i) % 2 == 0) buf.write(',');
    buf.write(rest[i]);
  }
  buf.write(',$last3');
  return buf.toString();
}

String employeeWeekRangeLabel() {
  final now = DateTime.now();
  final day = now.weekday;
  final start = now.subtract(Duration(days: day - 1));
  final end = start.add(const Duration(days: 6));
  String fmt(DateTime d) => '${d.day} ${_monthShort(d.month)}';
  return '${fmt(start)} – ${fmt(end)} ${now.year}';
}

String _monthShort(int m) {
  const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return names[m - 1];
}

String _fmtDate(dynamic v) {
  if (v == null) return '—';
  final d = DateTime.tryParse(v.toString());
  if (d == null) return '—';
  return '${d.day} ${_monthShort(d.month)} ${d.year}';
}

String _formatTime(DateTime? d) {
  if (d == null) return '—';
  final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
  final ampm = d.hour >= 12 ? 'PM' : 'AM';
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m $ampm';
}
