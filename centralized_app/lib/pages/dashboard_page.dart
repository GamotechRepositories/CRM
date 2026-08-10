import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_session.dart';
import '../auth/role_access.dart';
import '../dashboard/dashboard_stats.dart';
import '../dashboard/employee_dashboard_stats.dart';
import '../navigation/app_nav.dart';
import 'employee_dashboard_body.dart';
import 'site_coordinator_dashboard_body.dart';

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
                    Text(
                      'Welcome back, ${firstName.isEmpty ? 'Admin' : firstName}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    Text(
                      weekRangeLabel(),
                      style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 8),
                    if (_stats != null) DashboardStatsBody(stats: _stats!),
                  ],
                ),
    );
  }
}

/// Reusable dashboard stats layout (admin).
class DashboardStatsBody extends StatelessWidget {
  const DashboardStatsBody({super.key, required this.stats});
  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    return Column(
      children: [
        _kpiGrid(context, s),
        const SizedBox(height: 8),
        _revenuePanel(s),
        const SizedBox(height: 8),
        _breakdownPanel('Leads by Source', '${s.leadCount} total', s.leadsBySource),
        const SizedBox(height: 8),
        _breakdownPanel('Tasks Overview', '${s.taskCount} total', s.taskChart),
        const SizedBox(height: 8),
        _topEmployees(s),
        const SizedBox(height: 8),
        _activities(s),
        const SizedBox(height: 8),
        _miniStats(context, s),
      ],
    );
  }

  Widget _kpiGrid(BuildContext context, DashboardStats s) {
    final items = [
      _KpiData('Users', '${s.employeeCount}', s.employeeGrowth),
      _KpiData('Revenue', formatCompactInr(s.revenue), s.revenueGrowth),
      _KpiData('New Leads', '${s.newLeadsThisMonth}', s.leadGrowth),
      _KpiData('Open Deals', '${s.openDeals}', s.dealGrowth),
      _KpiData('Tasks Done', '${s.completedTasks}', s.taskGrowth),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items
          .map((k) => SizedBox(
                width: (MediaQuery.sizeOf(context).width - 26) / 2,
                child: _KpiCard(data: k),
              ))
          .toList(),
    );
  }

  Widget _revenuePanel(DashboardStats s) {
    return _Panel(
      title: 'Revenue Overview',
      subtitle: '${formatCompactInr(s.weekRevenue)} this week · avg ${formatCompactInr(s.weekAvg)}/day',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _MiniBox('Week', formatCompactInr(s.weekRevenue), const Color(0xFFEFF6FF))),
              const SizedBox(width: 6),
              Expanded(child: _MiniBox('Avg/day', formatCompactInr(s.weekAvg), const Color(0xFFF8FAFC))),
              const SizedBox(width: 6),
              Expanded(child: _MiniBox('Peak', s.peakDay.day, const Color(0xFFECFDF5))),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 88,
            child: _BarChart(
              values: s.revenueByDay.map((d) => d.revenue).toList(),
              labels: s.revenueByDay.map((d) => d.day).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _breakdownPanel(String title, String subtitle, List<NamedCount> data) {
    final total = data.fold<int>(0, (sum, d) => sum + d.value);
    return _Panel(
      title: title,
      subtitle: subtitle,
      child: data.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: Text('No data yet', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
            )
          : Column(
              children: data.take(6).map((d) {
                final pct = total == 0 ? 0.0 : d.value / total;
                final color = Color(d.color ?? 0xFF2563EB);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(d.name, style: const TextStyle(fontSize: 11, color: Color(0xFF334155)), overflow: TextOverflow.ellipsis),
                          ),
                          Text('${d.value} · ${(pct * 100).round()}%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(value: pct, minHeight: 5, backgroundColor: const Color(0xFFF1F5F9), color: color),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _topEmployees(DashboardStats s) {
    return _Panel(
      title: 'Top Performing Employees',
      subtitle: 'By lead count',
      child: s.topEmployees.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: Text('No performance data yet', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
            )
          : Column(
              children: [
                for (var i = 0; i < s.topEmployees.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          child: Text('${i + 1}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: i == 0 ? const Color(0xFFB45309) : const Color(0xFF64748B))),
                        ),
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: const Color(0xFF2563EB),
                          child: Text(
                            s.topEmployees[i].name.isNotEmpty ? s.topEmployees[i].name[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.topEmployees[i].name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                              Text(s.topEmployees[i].designation, style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)), overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(formatCompactInr(s.topEmployees[i].value), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                            Text('${s.topEmployees[i].count} leads', style: const TextStyle(fontSize: 9, color: Color(0xFF059669))),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _activities(DashboardStats s) {
    return _Panel(
      title: 'Recent Activities',
      subtitle: 'Latest across modules',
      child: s.activities.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: Text('No recent activity', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
            )
          : Column(
              children: s.activities.map((a) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                        child: Text(a.type[0], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, height: 1.25), maxLines: 2, overflow: TextOverflow.ellipsis),
                            Text(timeAgo(a.date), style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _miniStats(BuildContext context, DashboardStats s) {
    final items = [
      ('Projects', '${s.projectCount}', s.projectGrowth),
      ('Active', '${s.activeProjects}', 8.4),
      ('Clients', '${s.clientCount}', s.clientGrowth),
      ('Pending Leave', '${s.pendingLeave}', -5.6),
      ('Pending Invoices', '${s.pendingInvoices}', 7.3),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items
          .map((e) => SizedBox(
                width: (MediaQuery.sizeOf(context).width - 26) / 2,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.$1, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                      const SizedBox(height: 2),
                      Text(e.$2, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      Text(
                        '${e.$3 >= 0 ? '+' : ''}${e.$3}%',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: e.$3 >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626)),
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _KpiData {
  const _KpiData(this.title, this.value, this.change);
  final String title;
  final String value;
  final double change;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.data});
  final _KpiData data;

  @override
  Widget build(BuildContext context) {
    final positive = data.change >= 0;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data.title, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
          const SizedBox(height: 2),
          Text(data.value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: positive ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${positive ? '↑' : '↓'} ${data.change.abs()}% MoM',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: positive ? const Color(0xFF047857) : const Color(0xFFB91C1C)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, this.subtitle, required this.child});
  final String title;
  final String? subtitle;
  final Widget child;

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                if (subtitle != null) Text(subtitle!, style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
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

class _MiniBox extends StatelessWidget {
  const _MiniBox(this.label, this.value, this.bg);
  final String label;
  final String value;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  const _BarChart({required this.values, required this.labels});
  final List<double> values;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final maxV = values.fold<double>(1, (m, v) => v > m ? v : m);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < values.length; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: (values[i] / maxV).clamp(0.04, 1.0),
                        widthFactor: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: const Color(0xFF2563EB), borderRadius: BorderRadius.circular(3)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(labels[i], style: const TextStyle(fontSize: 8, color: Color(0xFF94A3B8))),
                ],
              ),
            ),
          ),
      ],
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
