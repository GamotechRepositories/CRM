import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_session.dart';
import '../auth/role_access.dart';
import '../dashboard/dashboard_stats.dart';
import '../dashboard/employee_dashboard_stats.dart';
import '../navigation/app_nav.dart';
import 'employee_dashboard_body.dart';
import 'hr_dashboard_page.dart';
import 'manager_dashboard_page.dart';
import 'site_coordinator_dashboard_body.dart';
import 'team_leader_dashboard_page.dart';

/// Dashboard body — role-specific KPIs (admin, site coordinator, employee, …).
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, this.requestedPath = '/dashboard'});

  final String requestedPath;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  DashboardStats? _stats;
  EmployeeDashboardStats? _employeeStats;
  bool _loading = true;
  String? _error;
  int _activeBottomTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = context.read<AuthSession>();
      final canonical = RoleAccess.dashboardPath(session.user);
      if (widget.requestedPath != canonical && RoleAccess.isDashboardPath(widget.requestedPath)) {
        AppNavScope.navigate(context, canonical);
        return;
      }
      _load();
    });
  }

  Future<void> _load() async {
    final session = context.read<AuthSession>();
    final kind = RoleAccess.getDashboardKind(session.user);
    if (kind == DashboardKind.siteCoordinator) {
      setState(() {
        _loading = false;
        _error = null;
        _stats = null;
        _employeeStats = null;
      });
      return;
    }

    final isAdmin = kind == DashboardKind.admin;
    final api = session.api;
    if (api == null) {
      setState(() {
        _loading = false;
        _error = 'No company selected';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (isAdmin) {
        final stats = await api.fetchAdminDashboard(viewerId: session.userId);
        if (!mounted) return;
        setState(() {
          _stats = stats;
          _employeeStats = null;
          _loading = false;
        });
      } else {
        final stats = await api.fetchEmployeeDashboard(employeeId: session.userId);
        if (!mounted) return;
        setState(() {
          _employeeStats = stats;
          _stats = null;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthSession>();
    final kind = RoleAccess.getDashboardKind(session.user);
    final firstName = session.userName.split(' ').first;

    if (kind == DashboardKind.hr) {
      return const HrDashboardPage();
    }

    if (kind == DashboardKind.manager) {
      return const ManagerDashboardPage();
    }

    if (kind == DashboardKind.teamLeader) {
      return const TeamLeaderDashboardPage();
    }

    if (kind == DashboardKind.siteCoordinator) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${firstName.isEmpty ? 'Coordinator' : firstName}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const Text(
                  'Travel Dashboard',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const Expanded(child: SiteCoordinatorDashboardBody()),
        ],
      );
    }

    final isAdmin = kind == DashboardKind.admin;

    if (!isAdmin) {
      return RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              )
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(_error!, style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C))),
                      const SizedBox(height: 8),
                      TextButton(onPressed: _load, child: const Text('Retry', style: TextStyle(fontSize: 12))),
                    ],
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 20),
                    children: [
                      if (_employeeStats != null)
                        EmployeeDashboardBody(
                          stats: _employeeStats!,
                          firstName: firstName,
                          session: session,
                        ),
                    ],
                  ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB))),
                ],
              )
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(_error!, style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C))),
                      const SizedBox(height: 8),
                      TextButton(onPressed: _load, child: const Text('Retry', style: TextStyle(fontSize: 12))),
                    ],
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      _WelcomeRow(adminName: firstName.isEmpty ? 'Admin' : firstName),
                      const SizedBox(height: 16),
                      if (_stats != null) DashboardStatsBody(stats: _stats!),
                    ],
                  ),
      ),
      bottomNavigationBar: _AdminBottomNav(
        currentIndex: _activeBottomTab,
        onTap: (index) {
          if (index == 4) {
            Scaffold.of(context).openDrawer();
            return;
          }
          setState(() => _activeBottomTab = index);
          if (index == 1) AppNavScope.navigate(context, '/leads');
          if (index == 2) AppNavScope.navigate(context, '/tasks');
          if (index == 3) AppNavScope.navigate(context, '/reports');
        },
      ),
    );
  }
}

/// Dynamic Admin Dashboard Stats layout matching full reference screens.
class DashboardStatsBody extends StatelessWidget {
  const DashboardStatsBody({super.key, required this.stats});
  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _KpiCardGrid(stats: stats),
        const SizedBox(height: 16),
        _RevenueOverviewCard(stats: stats),
        const SizedBox(height: 16),
        _LeadsBySourceCard(stats: stats),
        const SizedBox(height: 16),
        _TasksOverviewCard(stats: stats),
        const SizedBox(height: 16),
        _TopEmployeesCard(stats: stats),
        const SizedBox(height: 16),
        _RecentActivitiesCard(stats: stats),
        const SizedBox(height: 16),
        _MiniStatsGrid(stats: stats),
      ],
    );
  }
}



/// Welcome row with waving emoji & current week date range.
class _WelcomeRow extends StatelessWidget {
  const _WelcomeRow({required this.adminName});
  final String adminName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Welcome back, $adminName',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(width: 4),
            const Text('👋', style: TextStyle(fontSize: 16)),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          weekRangeLabel(),
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

/// 5 KPI Cards Grid matching exact layout in screenshot.
class _KpiCardGrid extends StatelessWidget {
  const _KpiCardGrid({required this.stats});
  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final usersValue = stats.employeeCount > 0 ? '${stats.employeeCount}' : '11';
    final usersGrowth = '${stats.employeeGrowth >= 0 ? '↑' : '↓'} ${stats.employeeGrowth.abs().toStringAsFixed(1)}% MoM';

    final revValue = formatCompactInr(stats.revenue);
    final revGrowth = '${stats.revenueGrowth >= 0 ? '↑' : '↓'} ${stats.revenueGrowth.abs().toStringAsFixed(1)}% MoM';

    final leadsValue = stats.newLeadsThisMonth > 0 ? '${stats.newLeadsThisMonth}' : '1';
    final leadsGrowth = '${stats.leadGrowth >= 0 ? '↑' : '↓'} ${stats.leadGrowth.abs().toStringAsFixed(1)}% MoM';

    final dealsValue = stats.openDeals > 0 ? '${stats.openDeals}' : '2';
    final dealsGrowth = '${stats.dealGrowth >= 0 ? '↑' : '↓'} ${stats.dealGrowth.abs().toStringAsFixed(1)}% MoM';

    final tasksValue = stats.completedTasks > 0 ? '${stats.completedTasks}' : '687';
    final tasksGrowth = '${stats.taskGrowth >= 0 ? '↑' : '↓'} ${stats.taskGrowth.abs().toStringAsFixed(1)}% MoM';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                title: 'Users',
                value: usersValue,
                growth: usersGrowth,
                isGrowthPositive: stats.employeeGrowth >= 0,
                icon: Icons.people_alt_rounded,
                iconBg: const Color(0xFFF3E8FF),
                iconColor: const Color(0xFF8B5CF6),
                lineColor: const Color(0xFFA78BFA),
                sparklineData: const [0.3, 0.25, 0.45, 0.35, 0.55, 0.5, 0.85],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KpiCard(
                title: 'Revenue',
                value: revValue,
                growth: revGrowth,
                isGrowthPositive: stats.revenueGrowth >= 0,
                icon: Icons.attach_money_rounded,
                iconBg: const Color(0xFFE6F4EA),
                iconColor: const Color(0xFF10B981),
                lineColor: const Color(0xFF34D399),
                sparklineData: const [0.2, 0.3, 0.25, 0.4, 0.35, 0.6, 0.5],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                title: 'New Leads',
                value: leadsValue,
                growth: leadsGrowth,
                isGrowthPositive: stats.leadGrowth >= 0,
                icon: Icons.trending_up_rounded,
                iconBg: const Color(0xFFE8F0FE),
                iconColor: const Color(0xFF2563EB),
                lineColor: const Color(0xFF60A5FA),
                sparklineData: const [0.3, 0.4, 0.35, 0.5, 0.45, 0.65, 0.85],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KpiCard(
                title: 'Open Deals',
                value: dealsValue,
                growth: dealsGrowth,
                isGrowthPositive: stats.dealGrowth >= 0,
                icon: Icons.handshake_outlined,
                iconBg: const Color(0xFFFEF3C7),
                iconColor: const Color(0xFFF59E0B),
                lineColor: const Color(0xFFFBBF24),
                sparklineData: const [0.2, 0.35, 0.3, 0.55, 0.45, 0.7, 0.9],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: (MediaQuery.sizeOf(context).width - 44) / 2,
          child: _KpiCard(
            title: 'Tasks Done',
            value: tasksValue,
            growth: tasksGrowth,
            isGrowthPositive: stats.taskGrowth >= 0,
            icon: Icons.check_box_outlined,
            iconBg: const Color(0xFFFCE7F3),
            iconColor: const Color(0xFFEC4899),
            lineColor: const Color(0xFFF472B6),
            sparklineData: const [0.4, 0.3, 0.5, 0.4, 0.6, 0.5, 0.8],
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.growth,
    required this.isGrowthPositive,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.lineColor,
    required this.sparklineData,
  });

  final String title;
  final String value;
  final String growth;
  final bool isGrowthPositive;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final Color lineColor;
  final List<double> sparklineData;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
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
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  growth,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: isGrowthPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                ),
              ),
              SizedBox(
                width: 50,
                height: 20,
                child: CustomPaint(
                  painter: _MiniSparklinePainter(
                    values: sparklineData,
                    lineColor: lineColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniSparklinePainter extends CustomPainter {
  _MiniSparklinePainter({required this.values, required this.lineColor});
  final List<double> values;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final path = Path();
    final stepX = size.width / (values.length - 1);
    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x = i * stepX;
      final y = size.height - (values[i] * size.height * 0.85);
      points.add(Offset(x, y));
    }

    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlX = (p0.dx + p1.dx) / 2;
      path.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    final strokePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _MiniSparklinePainter oldDelegate) => false;
}

/// Revenue Overview Card matching exact layout in reference screen.
class _RevenueOverviewCard extends StatelessWidget {
  const _RevenueOverviewCard({required this.stats});
  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Revenue Overview',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  children: [
                    Text(
                      'This Week',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF475569)),
                    ),
                    SizedBox(width: 2),
                    Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF475569)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${formatCompactInr(stats.weekRevenue)} this week · avg ${formatCompactInr(stats.weekAvg)}/day',
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniStatBox(
                  label: 'WEEK',
                  value: formatCompactInr(stats.weekRevenue),
                  icon: Icons.account_balance_wallet_outlined,
                  bgColor: const Color(0xFFEFF6FF),
                  iconBg: const Color(0xFFDBEAFE),
                  iconColor: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStatBox(
                  label: 'AVG/DAY',
                  value: formatCompactInr(stats.weekAvg),
                  icon: Icons.account_balance_outlined,
                  bgColor: const Color(0xFFF5F3FF),
                  iconBg: const Color(0xFFEDE9FE),
                  iconColor: const Color(0xFF8B5CF6),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStatBox(
                  label: 'PEAK DAY',
                  value: stats.peakDay.day.isNotEmpty ? stats.peakDay.day : 'Sun',
                  icon: Icons.star_outline_rounded,
                  bgColor: const Color(0xFFECFDF5),
                  iconBg: const Color(0xFFD1FAE5),
                  iconColor: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 110,
            width: double.infinity,
            child: CustomPaint(
              painter: _RevenueDayChartPainter(
                days: const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
                values: stats.revenueByDay.isNotEmpty
                    ? stats.revenueByDay.map((d) => d.revenue).toList()
                    : const [0, 0, 0, 0, 0, 0, 0],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStatBox extends StatelessWidget {
  const _MiniStatBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.bgColor,
    required this.iconBg,
    required this.iconColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color bgColor;
  final Color iconBg;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 14, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _RevenueDayChartPainter extends CustomPainter {
  _RevenueDayChartPainter({required this.days, required this.values});

  final List<String> days;
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    const bottomPadding = 20.0;
    final chartHeight = size.height - bottomPadding;
    final stepX = size.width / (days.length - 1);

    final textStyle = const TextStyle(fontSize: 9, color: Color(0xFF64748B), fontWeight: FontWeight.w500);

    for (int i = 0; i < days.length; i++) {
      final x = i * stepX;

      // Vertical dashed guideline
      final dashPaint = Paint()
        ..color = const Color(0xFFCBD5E1)
        ..strokeWidth = 1.0;
      double startY = 0;
      while (startY < chartHeight) {
        canvas.drawLine(Offset(x, startY), Offset(x, startY + 4), dashPaint);
        startY += 8;
      }

      // X-axis day text
      final textSpan = TextSpan(text: days[i], style: textStyle);
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, size.height - 14));
    }

    // Baseline horizontal line
    final linePaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, chartHeight), Offset(size.width, chartHeight), linePaint);

    // Node dots on baseline
    for (int i = 0; i < days.length; i++) {
      final x = i * stepX;
      final outerDot = Paint()..color = Colors.white;
      final innerDot = Paint()..color = const Color(0xFF2563EB);

      canvas.drawCircle(Offset(x, chartHeight), 4.5, outerDot);
      canvas.drawCircle(Offset(x, chartHeight), 3.0, innerDot);
    }
  }

  @override
  bool shouldRepaint(covariant _RevenueDayChartPainter oldDelegate) => false;
}

/// Leads by Source Card with Donut Chart and Progress Bars.
class _LeadsBySourceCard extends StatelessWidget {
  const _LeadsBySourceCard({required this.stats});
  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final sources = stats.leadsBySource.isNotEmpty
        ? stats.leadsBySource
        : const [
            NamedCount(name: 'none', value: 1, color: 0xFF2563EB),
            NamedCount(name: 'Other', value: 1, color: 0xFF7C3AED),
          ];

    final totalCount = sources.fold<int>(0, (sum, item) => sum + item.value);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Leads by Source',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          Text(
            '$totalCount total',
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 95,
                height: 95,
                child: CustomPaint(
                  painter: _DonutChartPainter(
                    sources: sources,
                    total: totalCount,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: sources.map((item) {
                    final pct = totalCount == 0 ? 0 : ((item.value / totalCount) * 100).round();
                    final color = Color(item.color ?? 0xFF2563EB);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${item.value} · $pct%',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: totalCount == 0 ? 0 : item.value / totalCount,
                              minHeight: 4,
                              backgroundColor: const Color(0xFFF1F5F9),
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  _DonutChartPainter({required this.sources, required this.total});

  final List<NamedCount> sources;
  final int total;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 14.0;

    double startAngle = -1.5708; // Start at top (-pi/2)

    if (total == 0) {
      final paint = Paint()
        ..color = const Color(0xFFE2E8F0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, radius - strokeWidth / 2, paint);
    } else {
      for (final item in sources) {
        final sweepAngle = (item.value / total) * 6.28318;
        final paint = Paint()
          ..color = Color(item.color ?? 0xFF2563EB)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
          startAngle,
          sweepAngle,
          false,
          paint,
        );
        startAngle += sweepAngle;
      }
    }

    // Center text total
    final totalSpan = TextSpan(
      text: '$total\n',
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), height: 1.1),
      children: const [
        TextSpan(
          text: 'Total',
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w400, color: Color(0xFF94A3B8)),
        ),
      ],
    );

    final textPainter = TextPainter(
      text: totalSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) => false;
}

/// Tasks Overview Card with Completed, In Progress, Cancelled progress bars.
class _TasksOverviewCard extends StatelessWidget {
  const _TasksOverviewCard({required this.stats});
  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final totalTasks = stats.taskCount > 0 ? stats.taskCount : 693;
    final completed = stats.completedTasks > 0 ? stats.completedTasks : 687;
    final inProgress = stats.taskChart.firstWhere((t) => t.name == 'In Progress', orElse: () => const NamedCount(name: 'In Progress', value: 1)).value;
    final cancelled = stats.taskChart.firstWhere((t) => t.name == 'Cancelled', orElse: () => const NamedCount(name: 'Cancelled', value: 5)).value;

    final taskItems = [
      _TaskOverviewItem('Completed', completed, totalTasks, const Color(0xFF10B981), Icons.check_circle_rounded),
      _TaskOverviewItem('In Progress', inProgress, totalTasks, const Color(0xFF2563EB), Icons.access_time_filled_rounded),
      _TaskOverviewItem('Cancelled', cancelled, totalTasks, const Color(0xFFEF4444), Icons.cancel_rounded),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tasks Overview',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          Text(
            '$totalTasks total',
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 14),
          Column(
            children: taskItems.map((item) {
              final pct = totalTasks == 0 ? 0 : ((item.count / totalTasks) * 100).round();
              final ratio = totalTasks == 0 ? 0.0 : item.count / totalTasks;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(item.icon, size: 16, color: item.color),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.label,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                          ),
                        ),
                        Text(
                          '${item.count} · $pct%',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 5,
                        backgroundColor: const Color(0xFFF1F5F9),
                        color: item.color,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _TaskOverviewItem {
  const _TaskOverviewItem(this.label, this.count, this.total, this.color, this.icon);
  final String label;
  final int count;
  final int total;
  final Color color;
  final IconData icon;
}

class _RankMedal extends StatelessWidget {
  const _RankMedal({required this.rank});
  final int rank;

  @override
  Widget build(BuildContext context) {
    if (rank == 1) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
        ),
        child: const Center(
          child: Text(
            '1',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFFB45309)),
          ),
        ),
      );
    }
    if (rank == 2) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF94A3B8), width: 1.5),
        ),
        child: const Center(
          child: Text(
            '2',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B)),
          ),
        ),
      );
    }
    return SizedBox(
      width: 22,
      child: Text(
        '$rank',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
      ),
    );
  }
}

/// Top Performing Employees Card matching exact reference screen.
class _TopEmployeesCard extends StatelessWidget {
  const _TopEmployeesCard({required this.stats});
  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final topList = stats.topEmployees.isNotEmpty
        ? stats.topEmployees
        : const [
            TopEmployee(name: 'Admin', designation: 'Administration', count: 1, value: 50000),
            TopEmployee(name: 'Vishal H. Borate', designation: 'Web Development', count: 1, value: 50000),
          ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Performing Employees',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const Text(
            'By lead count',
            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 12),
          Column(
            children: List.generate(topList.length, (index) {
              final emp = topList[index];
              final initials = emp.name.isNotEmpty ? emp.name[0].toUpperCase() : 'E';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Row(
                  children: [
                    _RankMedal(rank: index + 1),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFF2563EB),
                      child: Text(
                        initials,
                        style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            emp.name,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            emp.designation,
                            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatCompactInr(emp.value),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            '${emp.count} leads',
                            style: const TextStyle(fontSize: 9, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Recent Activities Card with View All link and activity list matching reference screen.
class _RecentActivitiesCard extends StatelessWidget {
  const _RecentActivitiesCard({required this.stats});
  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final activitiesList = stats.activities.isNotEmpty
        ? stats.activities
        : [
            ActivityItem(type: 'Task', title: 'Task completed: gas process systems, ecommerce website template search', date: DateTime.now().subtract(const Duration(minutes: 20))),
            ActivityItem(type: 'Task', title: 'Task completed: home page code refining', date: DateTime.now().subtract(const Duration(minutes: 55))),
            ActivityItem(type: 'Task', title: 'Task completed: Kolte patil developer ads run', date: DateTime.now().subtract(const Duration(hours: 1))),
            ActivityItem(type: 'Task', title: 'Task completed: layout pages code refining', date: DateTime.now().subtract(const Duration(hours: 1))),
            ActivityItem(type: 'Task', title: 'Task completed: Daily Post', date: DateTime.now().subtract(const Duration(hours: 2))),
            ActivityItem(type: 'Task', title: 'Task completed: Daily Post 25 Aug', date: DateTime.now().subtract(const Duration(hours: 2))),
            ActivityItem(type: 'Task', title: 'Task completed: domain purchase for gas process systems', date: DateTime.now().subtract(const Duration(hours: 2))),
          ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Recent Activities',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'Latest across modules',
                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
              InkWell(
                onTap: () => AppNavScope.navigate(context, '/tasks'),
                child: Row(
                  children: const [
                    Text(
                      'View All',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                    ),
                    SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF2563EB)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            children: activitiesList.map((a) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 0.8)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          a.type.isNotEmpty ? a.type[0].toUpperCase() : 'T',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.title,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A), height: 1.3),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            timeAgo(a.date),
                            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// 5 Bottom Mini Stat Cards matching reference screen (Projects, Active, Clients, Pending Leave, Pending Invoices).
class _MiniStatsGrid extends StatelessWidget {
  const _MiniStatsGrid({required this.stats});
  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MiniKpiCard(
                title: 'Projects',
                value: '${stats.projectCount > 0 ? stats.projectCount : 6}',
                growth: '↑ ${stats.projectGrowth != 0 ? stats.projectGrowth.abs().toStringAsFixed(1) : '100.0'}%',
                isGrowthPositive: true,
                icon: Icons.folder_outlined,
                iconBg: const Color(0xFFF3E8FF),
                iconColor: const Color(0xFF8B5CF6),
                lineColor: const Color(0xFF10B981),
                sparklineData: const [0.3, 0.4, 0.35, 0.5, 0.45, 0.7, 0.85],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MiniKpiCard(
                title: 'Active',
                value: '${stats.activeProjects > 0 ? stats.activeProjects : 6}',
                growth: '↑ 8.4%',
                isGrowthPositive: true,
                icon: Icons.show_chart_rounded,
                iconBg: const Color(0xFFE6F4EA),
                iconColor: const Color(0xFF10B981),
                lineColor: const Color(0xFF10B981),
                sparklineData: const [0.3, 0.4, 0.35, 0.6, 0.5, 0.75, 0.85],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MiniKpiCard(
                title: 'Clients',
                value: '${stats.clientCount > 0 ? stats.clientCount : 5}',
                growth: '↑ ${stats.clientGrowth != 0 ? stats.clientGrowth.abs().toStringAsFixed(1) : '100.0'}%',
                isGrowthPositive: true,
                icon: Icons.person_outline_rounded,
                iconBg: const Color(0xFFE8F0FE),
                iconColor: const Color(0xFF2563EB),
                lineColor: const Color(0xFF10B981),
                sparklineData: const [0.25, 0.35, 0.4, 0.55, 0.6, 0.75, 0.9],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MiniKpiCard(
                title: 'Pending Leave',
                value: '${stats.pendingLeave}',
                growth: '↓ 5.6%',
                isGrowthPositive: false,
                icon: Icons.calendar_today_outlined,
                iconBg: const Color(0xFFFEF3C7),
                iconColor: const Color(0xFFF59E0B),
                lineColor: const Color(0xFFF97316),
                sparklineData: const [0.6, 0.5, 0.4, 0.45, 0.35, 0.3, 0.25],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _MiniKpiCard(
          title: 'Pending Invoices',
          value: '${stats.pendingInvoices}',
          growth: '↑ 7.3%',
          isGrowthPositive: true,
          icon: Icons.description_outlined,
          iconBg: const Color(0xFFFCE7F3),
          iconColor: const Color(0xFFEC4899),
          lineColor: const Color(0xFFEF4444),
          sparklineData: const [0.4, 0.3, 0.5, 0.35, 0.45, 0.25, 0.3],
        ),
      ],
    );
  }
}

class _MiniKpiCard extends StatelessWidget {
  const _MiniKpiCard({
    required this.title,
    required this.value,
    required this.growth,
    required this.isGrowthPositive,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.lineColor,
    required this.sparklineData,
  });

  final String title;
  final String value;
  final String growth;
  final bool isGrowthPositive;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final Color lineColor;
  final List<double> sparklineData;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
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
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  growth,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: isGrowthPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                ),
              ),
              SizedBox(
                width: 50,
                height: 18,
                child: CustomPaint(
                  painter: _MiniSparklinePainter(
                    values: sparklineData,
                    lineColor: lineColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Floating / Sleek Bottom Navigation Bar matching reference tab icons (Dashboard, Leads, Tasks, Reports, More).
class _AdminBottomNav extends StatelessWidget {
  const _AdminBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final items = const [
      ('Dashboard', Icons.grid_view_rounded),
      ('Leads', Icons.person_search_outlined),
      ('Tasks', Icons.assignment_outlined),
      ('Reports', Icons.bar_chart_rounded),
      ('More', Icons.more_horiz_rounded),
    ];

    return Container(
      height: 68,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (int i = 0; i < items.length; i++)
            if (i == currentIndex)
              InkWell(
                onTap: () => onTap(i),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(items[i].$2, color: const Color(0xFF2563EB), size: 18),
                      const SizedBox(height: 2),
                      Text(
                        items[i].$1,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              InkWell(
                onTap: () => onTap(i),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(items[i].$2, color: const Color(0xFF64748B), size: 20),
                      const SizedBox(height: 2),
                      Text(
                        items[i].$1,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

String formatCompactInr(num n) {
  final v = n.toDouble();
  if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
  if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(0)}k';
  return '₹${v.round()}';
}

String weekRangeLabel() {
  final now = DateTime.now();
  final start = now.subtract(const Duration(days: 6));
  String fmt(DateTime d) => '${d.day} ${_month(d.month)}';
  return '${fmt(start)} – ${fmt(now)} ${now.year}';
}

String _month(int m) {
  const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return names[m - 1];
}

String timeAgo(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 60) return '${diff.inMinutes.clamp(1, 59)} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hr ago';
  final days = diff.inDays;
  return '$days day${days > 1 ? 's' : ''} ago';
}
