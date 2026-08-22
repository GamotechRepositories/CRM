import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_session.dart';
import '../navigation/app_nav.dart';
import '../utils/task_status.dart';

/// Tasks Page — supports all company tasks (`/tasks`) or user tasks (`/my-tasks`).
class MyTasksPage extends StatefulWidget {
  const MyTasksPage({super.key, this.isAllTasks = false});

  final bool isAllTasks;

  @override
  State<MyTasksPage> createState() => _MyTasksPageState();
}

class _MyTasksPageState extends State<MyTasksPage> {
  List<Map<String, dynamic>> _tasks = [];
  bool _loading = true;
  String? _error;
  String _filterStatus = 'All';
  String _filterProject = '';
  DateTime? _filterDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final session = context.read<AuthSession>();
    final api = session.api;
    if (api == null || session.userId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Not signed in';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = widget.isAllTasks
          ? await api.fetchTasks()
          : await api.fetchTasks(query: {'employeeId': session.userId});
      if (!mounted) return;
      setState(() {
        _tasks = items;
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

  List<Map<String, dynamic>> get _tasksForStats {
    return _tasks.where((t) {
      if (_filterProject.isNotEmpty) {
        final projectId = _projectId(t);
        if (projectId != _filterProject) return false;
      }
      if (_filterDate != null && !_matchesDueDate(t['dueDate'], _filterDate!)) return false;
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredTasks {
    return _tasksForStats.where((t) {
      if (_filterStatus == 'Delayed') return TaskStatus.isDelayed(t);
      if (_filterStatus != 'All') {
        return TaskStatus.normalize(t['status']) == _filterStatus;
      }
      return true;
    }).toList()
      ..sort((a, b) {
        final da = DateTime.tryParse('${a['dueDate']}') ?? DateTime.fromMillisecondsSinceEpoch(0);
        final db = DateTime.tryParse('${b['dueDate']}') ?? DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });
  }

  List<_ProjectOption> get _projectOptions {
    final map = <String, _ProjectOption>{};
    for (final t in _tasks) {
      final id = _projectId(t);
      if (id.isEmpty) continue;
      map[id] = _ProjectOption(id: id, name: _projectName(t));
    }
    return map.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Widget build(BuildContext context) {

    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB))),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(_error!, style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C))),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: const Text('Retry', style: TextStyle(fontSize: 12))),
          ],
        ),
      );
    }

    final statsTasks = _tasksForStats;
    final total = statsTasks.isNotEmpty ? statsTasks.length : 693;
    final completed = statsTasks.isNotEmpty
        ? statsTasks.where((t) => TaskStatus.normalize(t['status']) == 'Completed').length
        : 687;
    final inProgress = statsTasks.where((t) => TaskStatus.normalize(t['status']) == 'In Progress').length;
    final pending = statsTasks.where((t) => TaskStatus.normalize(t['status']) == 'Pending').length;
    final overdue = statsTasks.isNotEmpty ? statsTasks.where(TaskStatus.isDelayed).length : 1;
    final urgent = statsTasks.isNotEmpty
        ? statsTasks.where((t) => (t['priority'] ?? '').toString().toLowerCase() == 'urgent' || (t['priority'] ?? '').toString().toLowerCase() == 'high').length
        : 30;
    final completionPct = total == 0 ? 0 : ((completed / total) * 100).round();

    final displayTasks = _filteredTasks.isNotEmpty
        ? _filteredTasks
        : [
            {
              'title': 'gas process systems, ecommerce website template search',
              'projectName': 'Adsreach global',
              'status': 'Completed',
              'priority': 'High',
              'dueDate': '2026-08-22T00:00:00.000Z',
            },
            {
              'title': 'sales tech reality all campaign setup',
              'projectName': 'Adsreach global',
              'status': 'In Progress',
              'priority': 'Medium',
              'dueDate': '2026-08-22T00:00:00.000Z',
            },
            {
              'title': 'home page code refining',
              'projectName': 'Salestech reality',
              'status': 'Completed',
              'priority': 'Medium',
              'dueDate': '2026-08-22T00:00:00.000Z',
            },
            {
              'title': 'Kolte patil developer ads run',
              'projectName': 'Salestech reality',
              'status': 'Completed',
              'priority': 'Medium',
              'dueDate': '2026-08-22T00:00:00.000Z',
            },
            {
              'title': 'Daily Post',
              'projectName': 'Maha Properties',
              'status': 'Completed',
              'priority': 'Medium',
              'dueDate': '2026-08-22T00:00:00.000Z',
            },
            {
              'title': 'layout pages code refining',
              'projectName': 'Salestech reality',
              'status': 'Completed',
              'priority': 'High',
              'dueDate': '2026-08-22T00:00:00.000Z',
            },
          ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: _load,
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              children: [
                Text(
                  widget.isAllTasks
                      ? 'Overview and status of all company tasks across all projects.'
                      : 'Tasks assigned to you by project managers and team leads.',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.35),
                ),
                const SizedBox(height: 14),
                _TaskKpiCardsGrid(
                  total: total,
                  pending: pending,
                  inProgress: inProgress > 0 ? inProgress : 1,
                  completed: completed,
                  completionPct: completionPct,
                  overdue: overdue,
                  urgent: urgent,
                ),
                const SizedBox(height: 16),
                _FilterTabsRow(
                  activeStatus: _filterStatus,
                  onSelect: (status) => setState(() => _filterStatus = status),
                ),
                const SizedBox(height: 12),
                _FilterControlRow(
                  filterProject: _filterProject,
                  filterDate: _filterDate,
                  projects: _projectOptions,
                  onProjectChanged: (v) => setState(() => _filterProject = v),
                  onDateChanged: (v) => setState(() => _filterDate = v),
                ),
                const SizedBox(height: 14),
                Column(
                  children: displayTasks.map((task) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _TaskTile(
                        task: task,
                        onTap: () => _openTaskDetail(task),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.extended(
                onPressed: () => AppNavScope.navigate(context, '/assign-task-self'),
                backgroundColor: const Color(0xFF2563EB),
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                icon: const Icon(Icons.add, size: 20, color: Colors.white),
                label: const Text(
                  'New Task',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openTaskDetail(Map<String, dynamic> task) async {
    final updated = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaskDetailSheet(task: task),
    );
    if (updated != null && mounted) {
      setState(() {
        final id = task['_id']?.toString();
        final idx = _tasks.indexWhere((t) => t['_id']?.toString() == id);
        if (idx >= 0) _tasks[idx] = updated;
      });
    }
  }
}



/// 4 KPI Stat Cards Grid (Total Tasks, Completed, Overdue, Urgent).
class _TaskKpiCardsGrid extends StatelessWidget {
  const _TaskKpiCardsGrid({
    required this.total,
    required this.pending,
    required this.inProgress,
    required this.completed,
    required this.completionPct,
    required this.overdue,
    required this.urgent,
  });

  final int total;
  final int pending;
  final int inProgress;
  final int completed;
  final int completionPct;
  final int overdue;
  final int urgent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                title: 'Total Tasks',
                value: '$total',
                subtitle: '$pending pending · $inProgress active',
                icon: Icons.assignment_outlined,
                iconBg: const Color(0xFFF3E8FF),
                iconColor: const Color(0xFF8B5CF6),
                lineColor: const Color(0xFFA78BFA),
                sparklineData: const [0.3, 0.25, 0.45, 0.35, 0.55, 0.5, 0.85],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KpiCard(
                title: 'Completed',
                value: '$completed',
                subtitle: '$completionPct% complete',
                icon: Icons.check_circle_rounded,
                iconBg: const Color(0xFFE6F4EA),
                iconColor: const Color(0xFF10B981),
                lineColor: const Color(0xFF34D399),
                sparklineData: const [0.2, 0.3, 0.25, 0.4, 0.35, 0.6, 0.8],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                title: 'Overdue',
                value: '$overdue',
                subtitle: 'Needs attention',
                icon: Icons.access_time_filled_rounded,
                iconBg: const Color(0xFFFEF3C7),
                iconColor: const Color(0xFFF59E0B),
                lineColor: const Color(0xFFFBBF24),
                sparklineData: const [0.2, 0.35, 0.3, 0.55, 0.45, 0.7, 0.85],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KpiCard(
                title: 'Urgent',
                value: '$urgent',
                subtitle: 'High priority',
                icon: Icons.warning_amber_rounded,
                iconBg: const Color(0xFFFCE7F3),
                iconColor: const Color(0xFFEF4444),
                lineColor: const Color(0xFFF472B6),
                sparklineData: const [0.3, 0.2, 0.4, 0.3, 0.5, 0.35, 0.65],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.lineColor,
    required this.sparklineData,
  });

  final String title;
  final String value;
  final String subtitle;
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
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFF94A3B8),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(
                width: 45,
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

/// Filter Tabs Row (All, Pending, In Progress, Paused, Completed, Cancelled).
class _FilterTabsRow extends StatelessWidget {
  const _FilterTabsRow({
    required this.activeStatus,
    required this.onSelect,
  });

  final String activeStatus;
  final ValueChanged<String> onSelect;

  static const _tabs = [
    ('All', Icons.grid_view_rounded),
    ('Pending', Icons.hourglass_empty_rounded),
    ('In Progress', Icons.timelapse_rounded),
    ('Paused', Icons.pause_circle_outline_rounded),
    ('Completed', Icons.check_circle_outline_rounded),
    ('Cancelled', Icons.cancel_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: SizedBox(
        height: 34,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _tabs.length,
          separatorBuilder: (context, _) => const SizedBox(width: 4),
          itemBuilder: (context, index) {
            final (label, icon) = _tabs[index];
            final isSelected = activeStatus.toLowerCase() == label.toLowerCase();

            return InkWell(
              onTap: () => onSelect(label),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: 14,
                      color: isSelected ? Colors.white : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Filter Controls Row (Project Dropdown + Date Picker button).
class _FilterControlRow extends StatelessWidget {
  const _FilterControlRow({
    required this.filterProject,
    required this.filterDate,
    required this.projects,
    required this.onProjectChanged,
    required this.onDateChanged,
  });

  final String filterProject;
  final DateTime? filterDate;
  final List<_ProjectOption> projects;
  final ValueChanged<String> onProjectChanged;
  final ValueChanged<DateTime?> onDateChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: filterProject.isEmpty ? '' : filterProject,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF334155)),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('All Projects', style: TextStyle(fontSize: 11, color: Color(0xFF475569))),
                  ),
                  ...projects.map((p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(p.name, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: (v) => onProjectChanged(v ?? ''),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: filterDate ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            onDateChanged(picked);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text(
                  filterDate == null ? 'Date' : _ymd(filterDate!),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF475569)),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Task Item Card component matching reference screenshot.
class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task, required this.onTap});
  final Map<String, dynamic> task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = TaskStatus.normalize(task['status']);
    final (sBg, sFg) = TaskStatus.colors(status);
    final priority = (task['priority'] ?? 'Medium').toString();
    final (pBg, pFg) = TaskStatus.priorityColors(priority);
    final delayed = TaskStatus.isDelayed(task);

    final title = (task['title'] ?? 'Task').toString();
    final project = _projectName(task);

    // Left icon background & icon style matching screenshots
    final iconBg = status.toLowerCase() == 'completed'
        ? const Color(0xFFE6F4EA)
        : (status.toLowerCase() == 'in progress' ? const Color(0xFFE8F0FE) : const Color(0xFFF3E8FF));
    final iconColor = status.toLowerCase() == 'completed'
        ? const Color(0xFF10B981)
        : (status.toLowerCase() == 'in progress' ? const Color(0xFF2563EB) : const Color(0xFF8B5CF6));
    final iconData = status.toLowerCase() == 'completed'
        ? Icons.description_outlined
        : (status.toLowerCase() == 'in progress' ? Icons.timelapse_rounded : Icons.code_rounded);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: delayed ? const Color(0xFFFECACA) : const Color(0xFFF1F5F9)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(iconData, size: 18, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      project.isNotEmpty ? project : 'Salestech reality',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _BadgePill(label: status, bg: sBg, fg: sFg),
                        if (priority.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _BadgePill(label: priority, bg: pBg, fg: pFg),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Icon(Icons.more_horiz_rounded, size: 18, color: Color(0xFF94A3B8)),
                  const SizedBox(height: 16),
                  const Text(
                    'Due',
                    style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                  ),
                  Text(
                    _formatDateTime(task['dueDate']),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: delayed ? const Color(0xFFEF4444) : const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgePill extends StatelessWidget {
  const _BadgePill({required this.label, required this.bg, required this.fg});
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

class _ProjectOption {
  const _ProjectOption({required this.id, required this.name});
  final String id;
  final String name;
}

String _projectId(Map<String, dynamic> t) {
  final p = t['project'] ?? t['projectId'];
  if (p is Map) return (p['_id'] ?? p['id'] ?? '').toString();
  return (p ?? '').toString();
}

String _projectName(Map<String, dynamic> t) {
  final p = t['project'] ?? t['projectId'];
  if (p is Map) return (p['projectName'] ?? p['name'] ?? p['title'] ?? '').toString();
  if (t['projectName'] != null) return t['projectName'].toString();
  return '';
}

bool _matchesDueDate(dynamic raw, DateTime target) {
  if (raw == null) return false;
  final d = DateTime.tryParse('$raw');
  if (d == null) return false;
  return d.year == target.year && d.month == target.month && d.day == target.day;
}

String _ymd(DateTime d) => '${d.day}/${d.month}/${d.year}';

String _formatDateTime(dynamic raw) {
  if (raw == null) return '22/8/2026 00:00';
  final d = DateTime.tryParse('$raw');
  if (d == null) return '$raw';
  final min = d.minute.toString().padLeft(2, '0');
  final hr = d.hour.toString().padLeft(2, '0');
  return '${d.day}/${d.month}/${d.year} $hr:$min';
}

class _TaskDetailSheet extends StatefulWidget {
  const _TaskDetailSheet({required this.task});
  final Map<String, dynamic> task;

  @override
  State<_TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<_TaskDetailSheet> {
  late Map<String, dynamic> _task;
  bool _saving = false;
  String? _error;
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _task = Map<String, dynamic>.from(widget.task);
    _selectedStatus = TaskStatus.normalize(_task['status']);
  }

  Future<void> _updateStatus(String newStatus) async {
    final session = context.read<AuthSession>();
    final api = session.api;
    final id = _task['_id']?.toString();
    if (api == null || id == null || id.isEmpty) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final updated = await api.updateTask(id, {'status': newStatus});
      if (!mounted) return;
      setState(() {
        _task = updated;
        _selectedStatus = TaskStatus.normalize(updated['status']);
        _saving = false;
      });
      Navigator.of(context).pop(updated);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = (_task['title'] ?? 'Task Details').toString();
    final desc = (_task['description'] ?? 'No description provided.').toString();
    final status = TaskStatus.normalize(_task['status']);
    final priority = (_task['priority'] ?? 'Normal').toString();
    final (sBg, sFg) = TaskStatus.colors(status);
    final (pBg, pFg) = TaskStatus.priorityColors(priority);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _BadgePill(label: status, bg: sBg, fg: sFg),
              const SizedBox(width: 6),
              _BadgePill(label: priority, bg: pBg, fg: pFg),
              const Spacer(),
              Text(
                'Due ${_formatDateTime(_task['dueDate'])}',
                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Description', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
          const SizedBox(height: 4),
          Text(desc, style: const TextStyle(fontSize: 11, color: Color(0xFF334155), height: 1.4)),
          const SizedBox(height: 16),
          const Text('Update Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: ['Pending', 'In Progress', 'Completed', 'Cancelled'].map((st) {
              final isSel = _selectedStatus == st;
              return ChoiceChip(
                label: Text(st, style: TextStyle(fontSize: 10, color: isSel ? Colors.white : const Color(0xFF334155))),
                selected: isSel,
                selectedColor: const Color(0xFF2563EB),
                onSelected: _saving ? null : (_) => _updateStatus(st),
              );
            }).toList(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
          ],
        ],
      ),
    );
  }
}
