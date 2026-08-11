import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_session.dart';
import '../auth/role_access.dart';
import '../navigation/app_nav.dart';

class ManagerDashboardPage extends StatefulWidget {
  const ManagerDashboardPage({super.key});

  @override
  State<ManagerDashboardPage> createState() => _ManagerDashboardPageState();
}

class _ManagerDashboardPageState extends State<ManagerDashboardPage> {
  List<Map<String, dynamic>> _leads = [];
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _billings = [];

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    final session = context.read<AuthSession>();
    if (session.api == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        session.api!.fetchLeads().catchError((_) => <Map<String, dynamic>>[]),
        session.api!.fetchProjects().catchError((_) => <Map<String, dynamic>>[]),
        session.api!.fetchClients().catchError((_) => <Map<String, dynamic>>[]),
        session.api!.fetchTasks().catchError((_) => <Map<String, dynamic>>[]),
        session.api!.fetchEmployees().catchError((_) => <Map<String, dynamic>>[]),
        session.api!.fetchBillings().catchError((_) => <Map<String, dynamic>>[]),
      ]);

      if (!mounted) return;
      setState(() {
        _leads = results[0];
        _projects = results[1];
        _clients = results[2];
        _tasks = results[3];
        _employees = results[4];
        _billings = results[5];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  String _fmtINR(num n) {
    return '₹${n.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }

  double get _thisMonthRevenue {
    final now = DateTime.now();
    double sum = 0;
    for (final b in _billings) {
      final pay = b['paymentDetails'];
      final rawDate = pay is Map ? (pay['paymentDate'] ?? b['createdAt']) : b['createdAt'];
      if (rawDate != null) {
        final d = DateTime.tryParse(rawDate.toString());
        if (d != null && d.month == now.month && d.year == now.year) {
          sum += pay is Map ? (double.tryParse('${pay['amount']}') ?? 0.0) : 0.0;
        }
      }
    }
    return sum;
  }

  List<Map<String, dynamic>> get _topPerformingTeam {
    final empTaskMap = <String, Map<String, dynamic>>{};

    for (final t in _tasks) {
      final assigned = t['employee'] ?? t['assignedTo'];
      if (assigned == null) continue;

      String name = 'Team Member';
      String desig = 'Employee';
      String empId = '';

      if (assigned is Map) {
        empId = (assigned['_id'] ?? '').toString();
        name = (assigned['name'] ?? 'Team Member').toString();
        desig = RoleAccess.designationTitle(Map<String, dynamic>.from(assigned));
      } else {
        empId = assigned.toString();
        final match = _employees.firstWhere(
          (e) => (e['_id'] ?? '').toString() == empId,
          orElse: () => <String, dynamic>{},
        );
        if (match.isNotEmpty) {
          name = (match['name'] ?? 'Team Member').toString();
          desig = RoleAccess.designationTitle(match);
        }
      }

      if (empId.isEmpty) continue;
      if (!empTaskMap.containsKey(empId)) {
        empTaskMap[empId] = {
          'name': name,
          'role': desig,
          'completed': 0,
          'total': 0,
        };
      }

      empTaskMap[empId]!['total'] = (empTaskMap[empId]!['total'] as int) + 1;
      final status = (t['status'] ?? '').toString();
      if (status == 'Completed') {
        empTaskMap[empId]!['completed'] = (empTaskMap[empId]!['completed'] as int) + 1;
      }
    }

    final list = empTaskMap.values.toList();
    list.sort((a, b) => (b['completed'] as int).compareTo(a['completed'] as int));

    int rank = 1;
    return list.take(4).map((item) {
      final comp = item['completed'] as int;
      final tot = item['total'] as int;
      final target = tot > 5 ? tot : 5;
      final pct = (comp / target * 100).round();

      return {
        'rank': rank++,
        'name': item['name'],
        'role': item['role'],
        'completed': comp,
        'targetPct': pct,
        'onTarget': pct >= 100,
      };
    }).toList();
  }

  List<Map<String, dynamic>> get _recentActivities {
    final list = <Map<String, dynamic>>[];

    for (final l in _leads.take(4)) {
      final creator = l['generatedBy'];
      final name = creator is Map ? (creator['name'] ?? 'Sales Agent').toString() : 'Sales Agent';
      list.add({
        'name': name,
        'action': 'created a new lead',
        'detail': (l['businessName'] ?? l['name'] ?? 'Lead').toString(),
        'date': l['createdAt'],
      });
    }

    for (final t in _tasks.where((t) => (t['status'] ?? '') == 'Completed').take(3)) {
      final assign = t['assignedBy'] ?? t['assignedTo'];
      final name = assign is Map ? (assign['name'] ?? 'Team').toString() : 'Team';
      list.add({
        'name': name,
        'action': 'completed task',
        'detail': (t['title'] ?? 'Task').toString(),
        'date': t['completedAt'] ?? t['updatedAt'],
      });
    }

    list.sort((a, b) {
      final da = DateTime.tryParse('${a['date']}') ?? DateTime(2000);
      final db = DateTime.tryParse('${b['date']}') ?? DateTime(2000);
      return db.compareTo(da);
    });

    return list.take(5).toList();
  }

  String _fmtDate(dynamic raw) {
    if (raw == null) return '—';
    final d = DateTime.tryParse(raw.toString());
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final activeProjects = _projects.where((p) => (p['status'] ?? '') == 'In Progress').length;
    final totalLeads = _leads.length;
    final totalClients = _clients.length;
    final revMonth = _thisMonthRevenue;

    final completedTasks = _tasks.where((t) => (t['status'] ?? '') == 'Completed').length;
    final inProgressTasks = _tasks.where((t) => (t['status'] ?? '') == 'In Progress').length;
    final pendingTasks = _tasks.where((t) => (t['status'] ?? '') == 'Pending').length;
    final totalTasks = _tasks.length;

    final topTeam = _topPerformingTeam;
    final activities = _recentActivities;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Manager Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Header Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Color(0x1A0F172A), blurRadius: 8, offset: Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.white12,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.space_dashboard_outlined, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Manager Operations Hub', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text('Leads, Projects, Revenue & Team Tasks · ${_fmtDate(DateTime.now())}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Text('Error: $_error', style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12)),
                )
              else ...[
                // KPI Cards Grid
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = constraints.maxWidth < 600
                        ? (constraints.maxWidth - 8) / 2
                        : (constraints.maxWidth - 24) / 4;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: _buildStatCard(
                            title: 'Total Leads',
                            value: '$totalLeads',
                            subtitle: '+12% vs last month',
                            icon: Icons.filter_alt,
                            iconBg: const Color(0xFFEFF6FF),
                            iconColor: const Color(0xFF2563EB),
                            onTap: () => AppNavScope.navigate(context, '/leads'),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _buildStatCard(
                            title: 'Active Projects',
                            value: '$activeProjects',
                            subtitle: '${_projects.length} total projects',
                            icon: Icons.folder,
                            iconBg: const Color(0xFFECFDF5),
                            iconColor: const Color(0xFF059669),
                            onTap: () => AppNavScope.navigate(context, '/projects'),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _buildStatCard(
                            title: 'Total Clients',
                            value: '$totalClients',
                            subtitle: 'Active accounts',
                            icon: Icons.business,
                            iconBg: const Color(0xFFF3E8FF),
                            iconColor: const Color(0xFF9333EA),
                            onTap: () => AppNavScope.navigate(context, '/clients'),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _buildStatCard(
                            title: 'Revenue (This Month)',
                            value: _fmtINR(revMonth),
                            subtitle: 'Billed collections',
                            icon: Icons.payments,
                            iconBg: const Color(0xFFFFFBEB),
                            iconColor: const Color(0xFFD97706),
                            onTap: () => AppNavScope.navigate(context, '/revenue'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),

                // Tasks Overview Progress Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Tasks Breakdown', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          Text('Total Tasks: $totalTasks', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                        ],
                      ),
                      const SizedBox(height: 12),

                      _buildTaskProgressRow('Completed', completedTasks, totalTasks, const Color(0xFF10B981)),
                      const SizedBox(height: 10),
                      _buildTaskProgressRow('In Progress', inProgressTasks, totalTasks, const Color(0xFF2563EB)),
                      const SizedBox(height: 10),
                      _buildTaskProgressRow('Pending', pendingTasks, totalTasks, const Color(0xFFF59E0B)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Top Performing Team Members Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Top Performing Team Members', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          TextButton(
                            onPressed: () => AppNavScope.navigate(context, '/employees'),
                            child: const Text('View All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (topTeam.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: Text('No team task metrics yet', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: topTeam.length,
                          separatorBuilder: (_, index) => const SizedBox(height: 10),
                          itemBuilder: (context, idx) {
                            final item = topTeam[idx];
                            final name = item['name'] as String;
                            final role = item['role'] as String;
                            final completed = item['completed'] as int;
                            final pct = item['targetPct'] as int;
                            final onTarget = item['onTarget'] as bool;
                            final rank = item['rank'] as int;

                            return Row(
                              children: [
                                Text('#$rank', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                                const SizedBox(width: 10),
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: const Color(0xFFDBEAFE),
                                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'M', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E40AF), fontSize: 11)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                      Text('$role · $completed completed', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: onTarget ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text('$pct% target', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: onTarget ? const Color(0xFF047857) : const Color(0xFFB45309))),
                                ),
                              ],
                            );
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Recent Activities Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Recent Operation Activities', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 10),
                      if (activities.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: Text('No recent activity recorded', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: activities.length,
                          separatorBuilder: (_, index) => const SizedBox(height: 8),
                          itemBuilder: (context, idx) {
                            final act = activities[idx];
                            final name = act['name'] as String;
                            final action = act['action'] as String;
                            final detail = act['detail'] as String;
                            final date = _fmtDate(act['date']);

                            return Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: const Color(0xFFEFF6FF),
                                  child: const Icon(Icons.bolt, size: 14, color: Color(0xFF2563EB)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      RichText(
                                        text: TextSpan(
                                          text: name,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                          children: [
                                            TextSpan(text: ' $action', style: const TextStyle(fontWeight: FontWeight.normal, color: Color(0xFF475569))),
                                          ],
                                        ),
                                      ),
                                      Text(detail, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                                    ],
                                  ),
                                ),
                                Text(date, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                              ],
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskProgressRow(String label, int value, int total, Color color) {
    final pct = total > 0 ? (value / total * 100).toStringAsFixed(1) : '0.0';
    final progress = total > 0 ? (value / total).clamp(0.02, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
            Text('$value ($pct%)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: const Color(0xFFE2E8F0),
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(6)),
                  child: Icon(icon, size: 14, color: iconColor),
                ),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            ),
            Text(subtitle, style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }
}
