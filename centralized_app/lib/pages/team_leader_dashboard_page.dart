import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_session.dart';
import '../auth/role_access.dart';
import '../navigation/app_nav.dart';
import 'site_coordinator_dashboard_body.dart';

class TeamLeaderDashboardPage extends StatefulWidget {
  const TeamLeaderDashboardPage({super.key});

  @override
  State<TeamLeaderDashboardPage> createState() => _TeamLeaderDashboardPageState();
}

class _TeamLeaderDashboardPageState extends State<TeamLeaderDashboardPage> {
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _attendance = [];
  List<Map<String, dynamic>> _leaves = [];

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
        session.api!.fetchEmployees().catchError((_) => <Map<String, dynamic>>[]),
        session.api!.fetchTasks().catchError((_) => <Map<String, dynamic>>[]),
        session.api!.fetchProjects().catchError((_) => <Map<String, dynamic>>[]),
        session.api!.fetchAttendanceToday().catchError((_) => <Map<String, dynamic>>[]),
        session.api!.fetchLeave().catchError((_) => <Map<String, dynamic>>[]),
      ]);

      if (!mounted) return;
      setState(() {
        _employees = results[0];
        _tasks = results[1];
        _projects = results[2];
        _attendance = results[3];
        _leaves = results[4];
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

  List<Map<String, dynamic>> get _teamMembers {
    final session = context.read<AuthSession>();
    final leaderId = session.user?['_id']?.toString() ?? '';
    if (leaderId.isEmpty) return _employees.take(6).toList();

    final filtered = _employees.where((e) {
      final mgr = e['reportingManager'];
      final mId = mgr is Map ? (mgr['_id'] ?? '').toString() : (mgr ?? '').toString();
      return mId == leaderId;
    }).toList();

    return filtered.isNotEmpty ? filtered : _employees.take(6).toList();
  }

  int get _presentCount {
    final teamIds = _teamMembers.map((e) => (e['_id'] ?? '').toString()).toSet();
    return _attendance.where((a) {
      final emp = a['employee'];
      final eId = emp is Map ? (emp['_id'] ?? '').toString() : (emp ?? '').toString();
      final status = (a['status'] ?? '').toString();
      return teamIds.contains(eId) && ['Full Day', 'Half Day', 'In Progress', 'Present'].contains(status);
    }).length;
  }

  int get _overdueTasksCount {
    final now = DateTime.now();
    return _tasks.where((t) {
      final status = (t['status'] ?? '').toString();
      if (status == 'Completed') return false;
      final due = t['dueDate'];
      if (due == null) return false;
      final d = DateTime.tryParse(due.toString());
      if (d == null) return false;
      return d.isBefore(now);
    }).length;
  }

  List<Map<String, dynamic>> get _teamMemberStatuses {
    final now = DateTime.now();
    return _teamMembers.map((e) {
      final id = (e['_id'] ?? '').toString();
      final name = (e['name'] ?? 'Team Member').toString();
      final desig = RoleAccess.designationTitle(e);

      final att = _attendance.firstWhere(
        (a) {
          final emp = a['employee'];
          final eId = emp is Map ? (emp['_id'] ?? '').toString() : (emp ?? '').toString();
          return eId == id;
        },
        orElse: () => <String, dynamic>{},
      );

      final onLeave = _leaves.any((l) {
        final emp = l['employee'];
        final eId = emp is Map ? (emp['_id'] ?? '').toString() : (emp ?? '').toString();
        if (eId != id) return false;
        if ((l['status'] ?? '') != 'Approved') return false;
        final start = DateTime.tryParse('${l['startDate']}');
        final end = DateTime.tryParse('${l['endDate']}');
        if (start == null || end == null) return false;
        return now.isAfter(start.subtract(const Duration(days: 1))) && now.isBefore(end.add(const Duration(days: 1)));
      });

      String status = 'Offline';
      if (onLeave) {
        status = 'On Leave';
      } else if (att.isNotEmpty) {
        status = (att['checkOut'] != null) ? 'Away' : 'Online';
      }

      final empTasks = _tasks.where((t) {
        final assigned = t['employee'] ?? t['assignedTo'];
        final eId = assigned is Map ? (assigned['_id'] ?? '').toString() : (assigned ?? '').toString();
        return eId == id;
      }).toList();

      final comp = empTasks.where((t) => (t['status'] ?? '') == 'Completed').length;
      final open = empTasks.length - comp;
      final pct = empTasks.isNotEmpty ? ((comp / empTasks.length) * 100).round() : 0;

      return {
        'id': id,
        'name': name,
        'role': desig,
        'status': status,
        'openTasks': open,
        'progress': pct,
      };
    }).toList();
  }

  List<Map<String, dynamic>> get _recentActivities {
    final list = <Map<String, dynamic>>[];

    for (final t in _tasks.where((t) => (t['status'] ?? '') == 'Completed').take(4)) {
      final assign = t['assignedBy'] ?? t['assignedTo'];
      final name = assign is Map ? (assign['name'] ?? 'Team Member').toString() : 'Team Member';
      list.add({
        'icon': Icons.check_circle,
        'color': const Color(0xFF10B981),
        'bgColor': const Color(0xFFECFDF5),
        'title': '$name completed task',
        'subtitle': (t['title'] ?? 'Task').toString(),
        'date': t['completedAt'] ?? t['updatedAt'],
      });
    }

    for (final l in _leaves.where((l) => (l['status'] ?? '') == 'Pending').take(2)) {
      final emp = l['employee'];
      final name = emp is Map ? (emp['name'] ?? 'Team Member').toString() : 'Team Member';
      list.add({
        'icon': Icons.description,
        'color': const Color(0xFF2563EB),
        'bgColor': const Color(0xFFEFF6FF),
        'title': '$name submitted leave request',
        'subtitle': '${l['startDate'] ?? ''} – ${l['endDate'] ?? ''}',
        'date': l['createdAt'],
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
    final teamCount = _teamMembers.length;
    final present = _presentCount;
    final activeProjects = _projects.where((p) => (p['status'] ?? '') == 'In Progress').length;
    final totalTasks = _tasks.length;
    final overdueTasks = _overdueTasksCount;

    final teamStatuses = _teamMemberStatuses;
    final activities = _recentActivities;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Team Leader Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
              // Welcome Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Color(0x1A2563EB), blurRadius: 8, offset: Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.supervisor_account, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Team Leader Command Center', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text('Team tracking & project execution · ${_fmtDate(DateTime.now())}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
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
                            title: 'My Team Members',
                            value: '$teamCount',
                            subtitle: '$present present today',
                            icon: Icons.people,
                            iconBg: const Color(0xFFEFF6FF),
                            iconColor: const Color(0xFF2563EB),
                            onTap: () => AppNavScope.navigate(context, '/my-team'),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _buildStatCard(
                            title: 'Active Projects',
                            value: '$activeProjects',
                            subtitle: '${_projects.length} assigned',
                            icon: Icons.folder,
                            iconBg: const Color(0xFFECFDF5),
                            iconColor: const Color(0xFF059669),
                            onTap: () => AppNavScope.navigate(context, '/my-projects'),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _buildStatCard(
                            title: 'Team Tasks',
                            value: '$totalTasks',
                            subtitle: 'Assigned work items',
                            icon: Icons.task_alt,
                            iconBg: const Color(0xFFF3E8FF),
                            iconColor: const Color(0xFF9333EA),
                            onTap: () => AppNavScope.navigate(context, '/my-tasks'),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _buildStatCard(
                            title: 'Overdue Tasks',
                            value: '$overdueTasks',
                            subtitle: overdueTasks > 0 ? 'Requires attention' : 'All on track',
                            icon: Icons.warning_amber,
                            iconBg: overdueTasks > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                            iconColor: overdueTasks > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                            onTap: () => AppNavScope.navigate(context, '/my-tasks'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),

                // Travel Allowance & Route Map Section (For Team Leaders)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x04000000), blurRadius: 6, offset: Offset(0, 2)),
                    ],
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.directions_car_rounded, size: 16, color: Color(0xFF2563EB)),
                          SizedBox(width: 6),
                          Text('Travel Allowance & Route Map', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        ],
                      ),
                      SizedBox(height: 10),
                      SiteCoordinatorDashboardBody(shrinkWrap: true),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Team Members Attendance & Tasks Table
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
                          const Text('Team Status & Workload', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          TextButton(
                            onPressed: () => AppNavScope.navigate(context, '/my-team'),
                            child: const Text('View Team', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (teamStatuses.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: Text('No team members assigned', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: teamStatuses.length,
                          separatorBuilder: (_, index) => const SizedBox(height: 10),
                          itemBuilder: (context, idx) {
                            final m = teamStatuses[idx];
                            final name = m['name'] as String;
                            final role = m['role'] as String;
                            final status = m['status'] as String;
                            final openTasks = m['openTasks'] as int;
                            final progress = m['progress'] as int;

                            Color statusBg;
                            Color statusFg;
                            if (status == 'Online') {
                              statusBg = const Color(0xFFECFDF5);
                              statusFg = const Color(0xFF047857);
                            } else if (status == 'Away') {
                              statusBg = const Color(0xFFFFFBEB);
                              statusFg = const Color(0xFFB45309);
                            } else if (status == 'On Leave') {
                              statusBg = const Color(0xFFFCE7F3);
                              statusFg = const Color(0xFFBE185D);
                            } else {
                              statusBg = const Color(0xFFF1F5F9);
                              statusFg = const Color(0xFF475569);
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: const Color(0xFFEEF2FF),
                                      child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'T', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4F46E5), fontSize: 11)),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                          Text('$role · $openTasks open tasks', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(12)),
                                      child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusFg)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                LinearProgressIndicator(
                                  value: (progress / 100).clamp(0.02, 1.0),
                                  minHeight: 4,
                                  backgroundColor: const Color(0xFFE2E8F0),
                                  color: const Color(0xFF4F46E5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            );
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Project Progress Cards
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
                          const Text('Assigned Project Execution', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          TextButton(
                            onPressed: () => AppNavScope.navigate(context, '/my-projects'),
                            child: const Text('View All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_projects.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: Text('No projects assigned to team', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _projects.take(4).length,
                          separatorBuilder: (_, index) => const SizedBox(height: 10),
                          itemBuilder: (context, idx) {
                            final p = _projects[idx];
                            final pName = (p['projectName'] ?? p['title'] ?? 'Project').toString();
                            final pStatus = (p['status'] ?? 'In Progress').toString();

                            final projTasks = _tasks.where((t) {
                              final proj = t['project'];
                              final pId = proj is Map ? (proj['_id'] ?? '').toString() : (proj ?? '').toString();
                              return pId == (p['_id'] ?? '').toString();
                            }).toList();

                            final done = projTasks.where((t) => (t['status'] ?? '') == 'Completed').length;
                            final total = projTasks.length;
                            final pct = total > 0 ? ((done / total) * 100).round() : (pStatus == 'Completed' ? 100 : 25);

                            return Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(pName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                      ),
                                      Text('$pct%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  LinearProgressIndicator(
                                    value: (pct / 100).clamp(0.02, 1.0),
                                    minHeight: 6,
                                    backgroundColor: const Color(0xFFE2E8F0),
                                    color: const Color(0xFF059669),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ],
                              ),
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
                      const Text('Recent Team Activity', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 10),
                      if (activities.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: Text('No recent team activity', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: activities.length,
                          separatorBuilder: (_, index) => const SizedBox(height: 8),
                          itemBuilder: (context, idx) {
                            final act = activities[idx];
                            final icon = act['icon'] as IconData;
                            final color = act['color'] as Color;
                            final bgColor = act['bgColor'] as Color;
                            final title = act['title'] as String;
                            final subtitle = act['subtitle'] as String;
                            final date = _fmtDate(act['date']);

                            return Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
                                  child: Icon(icon, size: 16, color: color),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                      Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
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
