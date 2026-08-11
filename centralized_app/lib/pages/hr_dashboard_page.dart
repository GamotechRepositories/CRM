import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_session.dart';
import '../auth/role_access.dart';
import '../navigation/app_nav.dart';

const kDeptColors = [
  Color(0xFF3B82F6),
  Color(0xFF8B5CF6),
  Color(0xFF06B6D4),
  Color(0xFFF59E0B),
  Color(0xFF10B981),
  Color(0xFFEF4444),
  Color(0xFF6366F1),
  Color(0xFFEC4899),
];

class HrDashboardPage extends StatefulWidget {
  const HrDashboardPage({super.key});

  @override
  State<HrDashboardPage> createState() => _HrDashboardPageState();
}

class _HrDashboardPageState extends State<HrDashboardPage> {
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _leaves = [];
  List<Map<String, dynamic>> _todayAttendance = [];
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
        session.api!.fetchLeave().catchError((_) => <Map<String, dynamic>>[]),
        session.api!.fetchAttendanceToday().catchError((_) => <Map<String, dynamic>>[]),
      ]);

      if (!mounted) return;
      setState(() {
        _employees = results[0];
        _leaves = results[1];
        _todayAttendance = results[2];
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

  List<Map<String, dynamic>> get _activeEmployees => _employees.where((e) {
        final status = (e['employmentStatus'] ?? e['status'] ?? 'Active').toString();
        return status == 'Active';
      }).toList();

  List<Map<String, dynamic>> get _newJoinees {
    final now = DateTime.now();
    return _employees.where((e) {
      final rawDate = e['dateOfJoining'] ?? e['createdAt'];
      if (rawDate == null) return false;
      final d = DateTime.tryParse(rawDate.toString());
      if (d == null) return false;
      return d.month == now.month && d.year == now.year;
    }).toList();
  }

  int get _presentTodayCount {
    return _todayAttendance.where((a) {
      final status = (a['status'] ?? '').toString();
      return ['Full Day', 'Half Day', 'In Progress', 'Present'].contains(status);
    }).length;
  }

  int get _onLeaveTodayCount {
    final today = DateTime.now();
    return _leaves.where((l) {
      final status = (l['status'] ?? '').toString();
      if (status != 'Approved') return false;
      final start = DateTime.tryParse('${l['startDate']}');
      final end = DateTime.tryParse('${l['endDate']}');
      if (start == null || end == null) return false;
      return today.isAfter(start.subtract(const Duration(days: 1))) &&
          today.isBefore(end.add(const Duration(days: 1)));
    }).length;
  }

  int get _absentTodayCount {
    final active = _activeEmployees.length;
    final present = _presentTodayCount;
    final onLeave = _onLeaveTodayCount;
    final val = active - present - onLeave;
    return val < 0 ? 0 : val;
  }

  List<Map<String, dynamic>> get _deptBreakdown {
    final map = <String, int>{};
    for (final e in _employees) {
      final dept = (e['department'] ?? 'Unassigned').toString().trim();
      final key = dept.isNotEmpty ? dept : 'Unassigned';
      map[key] = (map[key] ?? 0) + 1;
    }
    final total = _employees.isNotEmpty ? _employees.length : 1;
    final list = map.entries.map((e) {
      final pct = (e.value / total * 100).round();
      return {
        'name': e.key,
        'count': e.value,
        'pct': pct,
      };
    }).toList();
    list.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    return list;
  }

  List<Map<String, dynamic>> get _recentJoinees {
    final list = [..._employees];
    list.sort((a, b) {
      final da = DateTime.tryParse('${a['dateOfJoining'] ?? a['createdAt']}') ?? DateTime(2000);
      final db = DateTime.tryParse('${b['dateOfJoining'] ?? b['createdAt']}') ?? DateTime(2000);
      return db.compareTo(da);
    });
    return list.take(5).toList();
  }

  List<Map<String, dynamic>> get _upcomingBirthdays {
    final now = DateTime.now();
    final list = <Map<String, dynamic>>[];

    for (final e in _employees) {
      final dobRaw = e['dateOfBirth'];
      if (dobRaw == null) continue;
      final dob = DateTime.tryParse(dobRaw.toString());
      if (dob == null) continue;

      var nextBday = DateTime(now.year, dob.month, dob.day);
      if (nextBday.isBefore(DateTime(now.year, now.month, now.day))) {
        nextBday = DateTime(now.year + 1, dob.month, dob.day);
      }

      final diffDays = nextBday.difference(DateTime(now.year, now.month, now.day)).inDays;
      list.add({
        ...e,
        'nextBday': nextBday,
        'diffDays': diffDays,
      });
    }

    list.sort((a, b) => (a['diffDays'] as int).compareTo(b['diffDays'] as int));
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
    final totalActive = _activeEmployees.length;
    final totalAll = _employees.length;
    final newJoinees = _newJoinees.length;
    final present = _presentTodayCount;
    final onLeave = _onLeaveTodayCount;
    final absent = _absentTodayCount;

    final presentPct = totalActive > 0 ? ((present / totalActive) * 100).toStringAsFixed(1) : '0.0';
    final deptList = _deptBreakdown;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('HR Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                    colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
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
                      child: const Icon(Icons.dashboard_customize, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('HR & Workforce Analytics', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text('Organization workforce stats · ${_fmtDate(DateTime.now())}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
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
                // KPI Cards Grid (Clickable)
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
                            title: 'Total Employees',
                            value: '$totalActive',
                            subtitle: '$totalAll records',
                            icon: Icons.people,
                            iconBg: const Color(0xFFEFF6FF),
                            iconColor: const Color(0xFF2563EB),
                            onTap: () => AppNavScope.navigate(context, '/employees'),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _buildStatCard(
                            title: 'New Joinees',
                            value: '+$newJoinees',
                            subtitle: 'This month',
                            icon: Icons.person_add_alt_1,
                            iconBg: const Color(0xFFECFDF5),
                            iconColor: const Color(0xFF059669),
                            onTap: () => AppNavScope.navigate(context, '/employees'),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _buildStatCard(
                            title: 'Present Today',
                            value: '$present',
                            subtitle: '$presentPct% active',
                            icon: Icons.check_circle_outline,
                            iconBg: const Color(0xFFF0FDF4),
                            iconColor: const Color(0xFF16A34A),
                            onTap: () => AppNavScope.navigate(context, '/attendance'),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _buildStatCard(
                            title: 'On Leave Today',
                            value: '$onLeave',
                            subtitle: '$absent absent',
                            icon: Icons.beach_access,
                            iconBg: const Color(0xFFFFFBEB),
                            iconColor: const Color(0xFFD97706),
                            onTap: () => AppNavScope.navigate(context, '/leave'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),

                // Attendance Breakdown Box (Clickable ➔ /attendance)
                GestureDetector(
                  onTap: () => AppNavScope.navigate(context, '/attendance'),
                  child: Container(
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
                            const Text('Today Attendance Summary', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            Text('$presentPct% Present', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Row(
                            children: [
                              if (present > 0)
                                Expanded(
                                  flex: present,
                                  child: Container(height: 8, color: const Color(0xFF10B981)),
                                ),
                              if (absent > 0)
                                Expanded(
                                  flex: absent,
                                  child: Container(height: 8, color: const Color(0xFFEF4444)),
                                ),
                              if (onLeave > 0)
                                Expanded(
                                  flex: onLeave,
                                  child: Container(height: 8, color: const Color(0xFFF59E0B)),
                                ),
                              if (present == 0 && absent == 0 && onLeave == 0)
                                Expanded(
                                  child: Container(height: 8, color: const Color(0xFFE2E8F0)),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildDotLabel('Present Today', '$present', const Color(0xFF10B981)),
                            _buildDotLabel('Absent Today', '$absent', const Color(0xFFEF4444)),
                            _buildDotLabel('On Leave', '$onLeave', const Color(0xFFF59E0B)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Employees by Department Breakdown Section (Clickable ➔ /module/departments)
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
                          Row(
                            children: [
                              const Icon(Icons.domain, size: 18, color: Color(0xFF4F46E5)),
                              const SizedBox(width: 6),
                              Text('Employees by Department (${deptList.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            ],
                          ),
                          TextButton(
                            onPressed: () => AppNavScope.navigate(context, '/module/departments'),
                            child: const Text('Manage', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (deptList.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Center(child: Text('No department data', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: deptList.length,
                          separatorBuilder: (_, index) => const SizedBox(height: 10),
                          itemBuilder: (context, idx) {
                            final dept = deptList[idx];
                            final name = dept['name'] as String;
                            final count = dept['count'] as int;
                            final pct = dept['pct'] as int;
                            final color = kDeptColors[idx % kDeptColors.length];

                            return GestureDetector(
                              onTap: () => AppNavScope.navigate(context, '/module/departments'),
                              child: Container(
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
                                        Row(
                                          children: [
                                            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                            const SizedBox(width: 8),
                                            Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                          ],
                                        ),
                                        Text('$count staff ($pct%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: (pct / 100).clamp(0.02, 1.0),
                                        minHeight: 6,
                                        backgroundColor: const Color(0xFFE2E8F0),
                                        color: color,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Quick Actions Grid
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
                      const Text('Quick HR Actions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              context,
                              label: 'Attendance',
                              icon: Icons.calendar_today,
                              color: const Color(0xFF10B981),
                              bgColor: const Color(0xFFECFDF5),
                              route: '/attendance',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildActionButton(
                              context,
                              label: 'Leaves',
                              icon: Icons.beach_access,
                              color: const Color(0xFFF59E0B),
                              bgColor: const Color(0xFFFFFBEB),
                              route: '/leave',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildActionButton(
                              context,
                              label: 'Payroll',
                              icon: Icons.payments,
                              color: const Color(0xFF8B5CF6),
                              bgColor: const Color(0xFFF3E8FF),
                              route: '/salaries',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              context,
                              label: 'Directory',
                              icon: Icons.people,
                              color: const Color(0xFF2563EB),
                              bgColor: const Color(0xFFEFF6FF),
                              route: '/employees',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildActionButton(
                              context,
                              label: 'Departments',
                              icon: Icons.domain,
                              color: const Color(0xFF4F46E5),
                              bgColor: const Color(0xFFEEF2FF),
                              route: '/module/departments',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildActionButton(
                              context,
                              label: 'Reports',
                              icon: Icons.analytics,
                              color: const Color(0xFFEC4899),
                              bgColor: const Color(0xFFFCE7F3),
                              route: '/reports',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Recent Joinees Section (Clickable ➔ /employees)
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
                          const Text('Recent Joinees', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          TextButton(
                            onPressed: () => AppNavScope.navigate(context, '/employees'),
                            child: const Text('View All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (_recentJoinees.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Center(child: Text('No employees found', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _recentJoinees.length,
                          separatorBuilder: (_, index) => const SizedBox(height: 8),
                          itemBuilder: (context, idx) {
                            final e = _recentJoinees[idx];
                            final name = (e['name'] ?? 'Employee').toString();
                            final desig = RoleAccess.designationTitle(e);
                            final doj = _fmtDate(e['dateOfJoining'] ?? e['createdAt']);

                            return GestureDetector(
                              onTap: () => AppNavScope.navigate(context, '/employees'),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: const Color(0xFFDBEAFE),
                                    child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'E', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E40AF), fontSize: 11)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                        Text(desig, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                      ],
                                    ),
                                  ),
                                  Text(doj, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Upcoming Birthdays Section (Clickable ➔ /employees)
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
                          const Text('Upcoming Birthdays', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          TextButton(
                            onPressed: () => AppNavScope.navigate(context, '/employees'),
                            child: const Text('View All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_upcomingBirthdays.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Center(child: Text('No birthdays on file', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _upcomingBirthdays.length,
                          separatorBuilder: (_, index) => const SizedBox(height: 8),
                          itemBuilder: (context, idx) {
                            final item = _upcomingBirthdays[idx];
                            final name = (item['name'] ?? 'Employee').toString();
                            final dob = _fmtDate(item['dateOfBirth']);
                            final diff = item['diffDays'] as int;

                            String badgeText = diff == 0 ? 'Today' : (diff == 1 ? 'Tomorrow' : 'In $diff days');

                            return GestureDetector(
                              onTap: () => AppNavScope.navigate(context, '/employees'),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: const Color(0xFFFCE7F3),
                                    child: const Icon(Icons.cake, color: Color(0xFFDB2777), size: 16),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                        Text(dob, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFCE7F3),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(badgeText, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFBE185D))),
                                  ),
                                ],
                              ),
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

  Widget _buildDotLabel(String label, String value, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('$label: ', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
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
          boxShadow: const [
            BoxShadow(color: Color(0x03000000), blurRadius: 3, offset: Offset(0, 1)),
          ],
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

  Widget _buildActionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required String route,
  }) {
    return GestureDetector(
      onTap: () => AppNavScope.navigate(context, route),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
