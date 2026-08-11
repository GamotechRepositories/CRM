import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_session.dart';
import '../utils/project_helpers.dart';
import '../utils/task_status.dart';

class TimesheetsPage extends StatefulWidget {
  const TimesheetsPage({super.key});

  @override
  State<TimesheetsPage> createState() => _TimesheetsPageState();
}

class _TimesheetsPageState extends State<TimesheetsPage> {
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _tasks = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    final session = context.read<AuthSession>();
    if (session.api == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        session.api!.fetchProjects(),
        session.api!.fetchTasks(),
      ]);

      if (!mounted) return;
      setState(() {
        _projects = results[0];
        _tasks = results[1].where((t) => !(t['_id']?.toString().startsWith('social-media-') ?? false)).toList();
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

  int _getTaskActualMinutes(Map<String, dynamic> task) {
    final status = TaskStatus.normalize(task['status']);
    if (status != 'Completed') return 0;

    final startRaw = task['startedAt'] ?? task['createdAt'];
    final endRaw = task['completedAt'] ?? task['updatedAt'];
    final start = startRaw != null ? DateTime.tryParse(startRaw.toString()) : null;
    final end = endRaw != null ? DateTime.tryParse(endRaw.toString()) : null;

    if (start == null || end == null || end.isBefore(start) || end.isAtSameMomentAs(start)) {
      return int.tryParse('${task['estimatedDurationMinutes']}') ?? 0;
    }

    return end.difference(start).inMinutes;
  }

  String _minutesToLabel(int minutes) {
    if (minutes <= 0) return '0h';
    final h = minutes ~/ 60;
    final rem = minutes % 60;
    if (h > 0 && rem > 0) return '${h}h ${rem}m';
    if (h > 0) return '${h}h';
    return '${rem}m';
  }

  List<Map<String, dynamic>> get _timesheetRows {
    final projectMap = <String, Map<String, dynamic>>{
      for (final p in _projects) (p['_id'] ?? '').toString(): p
    };

    final map = <String, Map<String, dynamic>>{};

    for (final task in _tasks) {
      final proj = task['project'];
      final projectId = proj is Map ? (proj['_id'] ?? '').toString() : (task['project'] ?? '').toString();
      if (projectId.isEmpty) continue;

      if (!map.containsKey(projectId)) {
        map[projectId] = {
          'projectId': projectId,
          'totalTasks': 0,
          'completedTasks': 0,
          'openTasks': 0,
          'estimatedMinutes': 0,
          'actualMinutes': 0,
        };
      }

      final row = map[projectId]!;
      row['totalTasks'] = (row['totalTasks'] as int) + 1;

      final est = int.tryParse('${task['estimatedDurationMinutes']}') ?? 0;
      row['estimatedMinutes'] = (row['estimatedMinutes'] as int) + (est > 0 ? est : 0);

      final status = TaskStatus.normalize(task['status']);
      if (status == 'Completed') {
        row['completedTasks'] = (row['completedTasks'] as int) + 1;
        row['actualMinutes'] = (row['actualMinutes'] as int) + _getTaskActualMinutes(task);
      } else {
        row['openTasks'] = (row['openTasks'] as int) + 1;
      }
    }

    final rows = map.values.map((row) {
      final pid = row['projectId'] as String;
      return {
        ...row,
        'project': projectMap[pid],
      };
    }).where((row) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase().trim();
      final p = (row['project'] as Map<String, dynamic>?) ?? {};
      final name = ProjectHelpers.projectName(p).toLowerCase();
      final client = ProjectHelpers.clientName(p).toLowerCase();
      return name.contains(q) || client.contains(q);
    }).toList()
      ..sort((a, b) => (b['actualMinutes'] as int).compareTo(a['actualMinutes'] as int));

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _timesheetRows;
    final totalActualMinutes = rows.fold<int>(0, (sum, r) => sum + (r['actualMinutes'] as int));
    final totalEstimatedMinutes = rows.fold<int>(0, (sum, r) => sum + (r['estimatedMinutes'] as int));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Project Timesheets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stat Cards
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'Projects Tracked',
                      value: '${rows.length}',
                      subtitle: 'Active Projects',
                      icon: Icons.folder_special,
                      iconBg: const Color(0xFFEFF6FF),
                      iconColor: const Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Logged Time',
                      value: _minutesToLabel(totalActualMinutes),
                      subtitle: 'Est. ${_minutesToLabel(totalEstimatedMinutes)}',
                      icon: Icons.timer,
                      iconBg: const Color(0xFFEEF2FF),
                      iconColor: const Color(0xFF4F46E5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Search Bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search timesheets by project or client...',
                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () => setState(() {
                              _searchCtrl.clear();
                              _searchQuery = '';
                            }),
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 14),

              // Body content
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
              else if (rows.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: const [
                      Icon(Icons.access_time_outlined, size: 48, color: Color(0xFF94A3B8)),
                      SizedBox(height: 10),
                      Text(
                        'No project timesheet data available',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Logged hours from completed project tasks will automatically compile here.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: rows.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final row = rows[idx];
                    return _buildTimesheetCard(row);
                  },
                ),
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
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                ),
                Text(subtitle, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimesheetCard(Map<String, dynamic> row) {
    final project = (row['project'] as Map<String, dynamic>?) ?? {};
    final projectName = ProjectHelpers.projectName(project);
    final clientName = ProjectHelpers.clientName(project);
    final totalTasks = row['totalTasks'] as int;
    final completedTasks = row['completedTasks'] as int;
    final openTasks = row['openTasks'] as int;
    final estMin = row['estimatedMinutes'] as int;
    final actMin = row['actualMinutes'] as int;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.av_timer, color: Color(0xFF4F46E5), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(projectName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 2),
                      Text('Client: $clientName', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 18),

            // Metrics Grid Row
            Row(
              children: [
                Expanded(
                  child: _badgeBlock(
                    label: 'Tasks Total',
                    value: '$totalTasks',
                    bg: const Color(0xFFF1F5F9),
                    fg: const Color(0xFF475569),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _badgeBlock(
                    label: 'Completed',
                    value: '$completedTasks',
                    bg: const Color(0xFFECFDF5),
                    fg: const Color(0xFF047857),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _badgeBlock(
                    label: 'Open',
                    value: '$openTasks',
                    bg: const Color(0xFFFFFBEB),
                    fg: const Color(0xFFB45309),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Time Spent Summary Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Estimated Time', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                      const SizedBox(height: 2),
                      Text(_minutesToLabel(estMin), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                    ],
                  ),
                  Container(height: 24, width: 1, color: const Color(0xFFCBD5E1)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Actual Time Logged', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                      const SizedBox(height: 2),
                      Text(_minutesToLabel(actMin), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badgeBlock({required String label, required String value, required Color bg, required Color fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 9, color: fg, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: fg)),
        ],
      ),
    );
  }
}
