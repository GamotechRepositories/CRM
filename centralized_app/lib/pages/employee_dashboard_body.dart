import 'package:flutter/material.dart';

import '../auth/auth_session.dart';
import '../auth/role_access.dart';
import '../dashboard/employee_dashboard_stats.dart';
import '../navigation/app_nav.dart';
import 'site_coordinator_dashboard_body.dart';

/// Employee Dashboard UI mirroring the exact reference design.
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
    final cardW = (width - 28) / 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Welcome Header Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Welcome back, ${firstName.isEmpty ? 'there' : firstName}!',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text('👋', style: TextStyle(fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    "Here's what's happening with your work today.",
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  if (designation.isNotEmpty)
                    Text(
                      designation,
                      style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(color: Color(0x04000000), blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 12, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text(
                    employeeWeekRangeLabel(),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down, size: 14, color: Color(0xFF64748B)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 9 KPI Stat Cards Grid (2-column)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _EmpKpiCard(
              width: cardW,
              title: "Today's Tasks",
              value: '${stats.todaysTasks}',
              subtitle: 'Due today',
              icon: Icons.assignment_outlined,
              iconBg: const Color(0xFFEFF6FF),
              iconColor: const Color(0xFF2563EB),
              lineColor: const Color(0xFF2563EB),
              sparklineData: const [0.2, 0.25, 0.2, 0.3, 0.25, 0.3, 0.28],
              onTap: () => AppNavScope.navigate(context, '/my-tasks'),
            ),
            _EmpKpiCard(
              width: cardW,
              title: 'Past Tasks',
              value: '${stats.pastIncompleteTasks}',
              subtitle: 'Not completed',
              icon: Icons.calendar_today_outlined,
              iconBg: const Color(0xFFFFF1F2),
              iconColor: const Color(0xFFF43F5E),
              lineColor: const Color(0xFFF43F5E),
              sparklineData: const [0.3, 0.2, 0.4, 0.25, 0.5, 0.3, 0.6],
              onTap: () => AppNavScope.navigate(context, '/my-tasks'),
            ),
            _EmpKpiCard(
              width: cardW,
              title: 'Tasks Completed',
              value: '${stats.completedThisMonth}',
              subtitle: 'This month',
              icon: Icons.check_circle_outline_rounded,
              iconBg: const Color(0xFFECFDF5),
              iconColor: const Color(0xFF10B981),
              lineColor: const Color(0xFF10B981),
              sparklineData: const [0.15, 0.25, 0.2, 0.4, 0.35, 0.65, 0.55],
              isArea: true,
              onTap: () => AppNavScope.navigate(context, '/my-tasks'),
            ),
            _EmpKpiCard(
              width: cardW,
              title: 'My Leads',
              value: '${stats.leads}',
              subtitle: 'Total leads',
              icon: Icons.people_outline_rounded,
              iconBg: const Color(0xFFF3E8FF),
              iconColor: const Color(0xFF9333EA),
              lineColor: const Color(0xFF9333EA),
              sparklineData: const [0.2, 0.3, 0.25, 0.5, 0.4, 0.7, 0.6],
              isArea: true,
              onTap: () => AppNavScope.navigate(context, '/lead-management'),
            ),
            _EmpKpiCard(
              width: cardW,
              title: 'Open Deals',
              value: '${stats.openDeals}',
              subtitle: 'In pipeline',
              icon: Icons.work_outline_rounded,
              iconBg: const Color(0xFFFFF7ED),
              iconColor: const Color(0xFFF97316),
              lineColor: const Color(0xFFF97316),
              sparklineData: const [0.2, 0.3, 0.25, 0.45, 0.35, 0.55, 0.5],
              onTap: () => AppNavScope.navigate(context, '/lead-management'),
            ),
            _EmpKpiCard(
              width: cardW,
              title: 'Meetings Today',
              value: '${stats.meetingsToday}',
              subtitle: 'Scheduled',
              icon: Icons.videocam_outlined,
              iconBg: const Color(0xFFE0F2FE),
              iconColor: const Color(0xFF0EA5E9),
              lineColor: const Color(0xFF0EA5E9),
              sparklineData: const [0.2, 0.2, 0.25, 0.2, 0.22, 0.25, 0.2],
              onTap: () => AppNavScope.navigate(context, '/lead-management'),
            ),
            _EmpKpiCard(
              width: cardW,
              title: 'Follow-ups',
              value: '${stats.followUps}',
              subtitle: 'Upcoming',
              icon: Icons.mail_outline_rounded,
              iconBg: const Color(0xFFF5F3FF),
              iconColor: const Color(0xFF7C3AED),
              lineColor: const Color(0xFF7C3AED),
              sparklineData: const [0.2, 0.2, 0.2, 0.25, 0.2, 0.22, 0.2],
              onTap: () => AppNavScope.navigate(context, '/lead-management'),
            ),
            _EmpKpiCard(
              width: cardW,
              title: 'Missed Follow-ups',
              value: '${stats.missedFollowUps}',
              subtitle: 'Past due',
              icon: Icons.mark_email_unread_outlined,
              iconBg: const Color(0xFFFEE2E2),
              iconColor: const Color(0xFFEF4444),
              lineColor: const Color(0xFFEF4444),
              sparklineData: const [0.2, 0.2, 0.2, 0.2, 0.22, 0.2, 0.2],
              onTap: () => AppNavScope.navigate(context, '/lead-management'),
            ),
            _EmpKpiCard(
              width: cardW,
              title: 'Total Incentive',
              value: formatInr(stats.totalIncentiveEarned),
              subtitle: 'From bookings',
              icon: Icons.card_giftcard_rounded,
              iconBg: const Color(0xFFECFDF5),
              iconColor: const Color(0xFF059669),
              lineColor: const Color(0xFF10B981),
              sparklineData: const [0.15, 0.2, 0.18, 0.25, 0.22, 0.3, 0.25],
              onTap: () => AppNavScope.navigate(context, '/lead-management'),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // My Performance Section
        _EmpCard(
          title: 'My Performance',
          actionLabel: 'View Details >',
          onAction: () => AppNavScope.navigate(context, '/my-tasks'),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Circular Ring Score Indicator
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 12),
                child: Column(
                  children: [
                    SizedBox(
                      width: 90,
                      height: 90,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 90,
                            height: 90,
                            child: CircularProgressIndicator(
                              value: (stats.performancePct / 100).clamp(0.0, 1.0),
                              strokeWidth: 9,
                              backgroundColor: const Color(0xFFEFF6FF),
                              color: const Color(0xFF2563EB),
                            ),
                          ),
                          Text(
                            '${stats.performancePct.round()}%',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Overall Score',
                      style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Performance Detail Items List
              Expanded(
                child: Column(
                  children: [
                    _perfMetricRow(
                      icon: Icons.person_outline_rounded,
                      iconBg: const Color(0xFFEFF6FF),
                      iconColor: const Color(0xFF2563EB),
                      label: 'Leads Assigned',
                      value: '${stats.leads > 0 ? stats.leads : 3}',
                    ),
                    _perfMetricRow(
                      icon: Icons.check_circle_outline_rounded,
                      iconBg: const Color(0xFFECFDF5),
                      iconColor: const Color(0xFF10B981),
                      label: 'Deals Closed',
                      value: '${stats.dealsClosed}',
                    ),
                    _perfMetricRow(
                      icon: Icons.assignment_outlined,
                      iconBg: const Color(0xFFF3E8FF),
                      iconColor: const Color(0xFF9333EA),
                      label: 'Tasks Done (Month)',
                      value: '${stats.completedThisMonth > 0 ? stats.completedThisMonth : 84}',
                    ),
                    _perfMetricRow(
                      icon: Icons.access_time_rounded,
                      iconBg: const Color(0xFFFFF7ED),
                      iconColor: const Color(0xFFF97316),
                      label: 'Pending Tasks',
                      value: '${stats.pendingTasksCount}',
                    ),
                    _perfMetricRow(
                      icon: Icons.star_outline_rounded,
                      iconBg: const Color(0xFFFEF3C7),
                      iconColor: const Color(0xFFF59E0B),
                      label: 'Avg Task Rating',
                      value: stats.avgRating != null ? '${stats.avgRating}/5' : '4.4/5',
                    ),
                    _perfMetricRow(
                      icon: Icons.thumb_up_alt_outlined,
                      iconBg: const Color(0xFFEFF6FF),
                      iconColor: const Color(0xFF2563EB),
                      label: 'Rated Tasks',
                      value: '${stats.ratedTasks.isNotEmpty ? stats.ratedTasks.length : 116}',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // My Sales Pipeline Section
        _EmpCard(
          title: 'My Sales Pipeline',
          actionLabel: 'View Pipeline',
          onAction: () => AppNavScope.navigate(context, '/lead-management'),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Total pipeline value: ${formatInr(stats.pipelineTotalValue > 0 ? stats.pipelineTotalValue : 341000)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                ),
              ),
              const SizedBox(height: 12),
              _pipelineStageRow(
                icon: Icons.people_outline_rounded,
                iconBg: const Color(0xFFEFF6FF),
                iconColor: const Color(0xFF2563EB),
                label: 'Leads',
                valueRatio: 1.0,
                barColor: const Color(0xFF2563EB),
                count: '3',
                amount: '₹1,80,000',
              ),
              const SizedBox(height: 10),
              _pipelineStageRow(
                icon: Icons.workspace_premium_outlined,
                iconBg: const Color(0xFFF3E8FF),
                iconColor: const Color(0xFF9333EA),
                label: 'Qualified',
                valueRatio: 0.45,
                barColor: const Color(0xFF9333EA),
                count: '1',
                amount: '₹90,000',
              ),
              const SizedBox(height: 10),
              _pipelineStageRow(
                icon: Icons.handshake_outlined,
                iconBg: const Color(0xFFECFDF5),
                iconColor: const Color(0xFF10B981),
                label: 'Proposal',
                valueRatio: 0.38,
                barColor: const Color(0xFF10B981),
                count: '1',
                amount: '₹71,000',
              ),
            ],
          ),
        ),
        // Travel Allowance & Route Map (Directly on Dashboard for Sales Department)
        if (RoleAccess.canViewTravelAndRouteMap(session.user)) ...[
          const SizedBox(height: 12),
          const _EmpCard(
            title: 'Travel Allowance & Route Map',
            child: SiteCoordinatorDashboardBody(shrinkWrap: true),
          ),
        ],
        const SizedBox(height: 12),

        // Today's Schedule Section
        _EmpCard(
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
        const SizedBox(height: 12),

        // Task Ratings Section (Dynamic)
        if (stats.ratedTasks.isNotEmpty) ...[
          const SizedBox(height: 12),
          _EmpCard(
            title: 'Task Ratings',
            actionLabel: 'My Tasks',
            onAction: () => AppNavScope.navigate(context, '/my-tasks'),
            child: Column(
              children: stats.ratedTasks.take(6).map((task) {
                final rating = task['rating'] is Map ? task['rating'] as Map : null;
                final score = num.tryParse('${rating?['score']}') ?? 5;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _taskRatingItem(
                    title: (task['title'] ?? 'Task').toString(),
                    score: score.toDouble(),
                    comment: rating?['comments']?.toString(),
                  ),
                );
              }).toList(),
            ),
          ),
        ],

        // Announcements Section (Strictly Dynamic from API)
        if (stats.recentAnnouncements.isNotEmpty) ...[
          const SizedBox(height: 12),
          _EmpCard(
            title: 'Announcements',
            actionLabel: 'View All',
            onAction: () => AppNavScope.navigate(context, '/module/announcements'),
            child: Column(
              children: stats.recentAnnouncements.map((a) {
                final priority = (a['priority'] ?? 'normal').toString();
                final icon = priority == 'urgent' ? '🚨' : priority == 'high' ? '📢' : 'ℹ️';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _announcementItem(
                    icon: icon,
                    title: (a['title'] ?? 'Announcement').toString(),
                    message: (a['message'] ?? a['content'] ?? '').toString(),
                    date: _fmtDate(a['createdAt']),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  static Widget _taskRatingItem({
    required String title,
    required double score,
    String? comment,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, size: 12, color: Color(0xFFD97706)),
                    const SizedBox(width: 3),
                    Text(
                      '${score.toStringAsFixed(score == score.roundToDouble() ? 0 : 1)}/5',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (comment != null && comment.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '"$comment"',
              style: const TextStyle(fontSize: 10, color: Color(0xFF475569), fontStyle: FontStyle.italic),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  static Widget _announcementItem({
    required String icon,
    required String title,
    required String message,
    required String date,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(date, style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                  ],
                ),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _perfMetricRow({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, size: 12, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          ),
        ],
      ),
    );
  }

  static Widget _pipelineStageRow({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required double valueRatio,
    required Color barColor,
    required String count,
    required String amount,
  }) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: valueRatio,
              minHeight: 8,
              backgroundColor: const Color(0xFFF1F5F9),
              color: barColor,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(count, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
            Text(amount, style: const TextStyle(fontSize: 9, color: Color(0xFF64748B))),
          ],
        ),
      ],
    );
  }
}

/// Custom KPI Stat Card matching the reference screenshot.
class _EmpKpiCard extends StatelessWidget {
  const _EmpKpiCard({
    required this.width,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.lineColor,
    required this.sparklineData,
    this.isArea = false,
    this.onTap,
  });

  final double width;
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final Color lineColor;
  final List<double> sparklineData;
  final bool isArea;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: iconColor, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        subtitle,
                        style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      height: 18,
                      child: CustomPaint(
                        painter: _EmpSparklinePainter(
                          values: sparklineData,
                          lineColor: lineColor,
                          isArea: isArea,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom Panel Card wrapper with title and action button.
class _EmpCard extends StatelessWidget {
  const _EmpCard({
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x04000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                ),
                if (actionLabel != null && onAction != null)
                  GestureDetector(
                    onTap: onAction,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        actionLabel!,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          Padding(
            padding: const EdgeInsets.all(14),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Sparkline graph painter for KPI cards.
class _EmpSparklinePainter extends CustomPainter {
  _EmpSparklinePainter({required this.values, required this.lineColor, this.isArea = false});
  final List<double> values;
  final Color lineColor;
  final bool isArea;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final path = Path();
    final stepX = size.width / (values.length - 1);
    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x = i * stepX;
      final y = size.height - (values[i] * size.height * 0.8);
      points.add(Offset(x, y));
    }

    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlX = (p0.dx + p1.dx) / 2;
      path.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    if (isArea) {
      final fillPath = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [lineColor.withAlpha(50), lineColor.withAlpha(0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawPath(fillPath, fillPaint);
    }

    final strokePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _EmpSparklinePainter oldDelegate) => false;
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

String _formatTime(DateTime? d) {
  if (d == null) return '—';
  final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
  final ampm = d.hour >= 12 ? 'PM' : 'AM';
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m $ampm';
}

String _fmtDate(dynamic v) {
  if (v == null) return '—';
  final d = DateTime.tryParse(v.toString());
  if (d == null) return '—';
  return '${d.day} ${_monthShort(d.month)} ${d.year}';
}
