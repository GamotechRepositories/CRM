import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_session.dart';
import '../navigation/app_nav.dart';
import '../utils/task_status.dart';
import '../api/api_cache.dart';
import '../services/notification_service.dart';

/// Tasks Page — supports all company tasks (`/tasks`) or user tasks (`/my-tasks`).
class MyTasksPage extends StatefulWidget {
  const MyTasksPage({super.key, this.isAllTasks = false, this.initialStatus = 'All'});

  final bool isAllTasks;
  final String initialStatus;

  @override
  State<MyTasksPage> createState() => _MyTasksPageState();
}

class _MyTasksPageState extends State<MyTasksPage> {
  List<Map<String, dynamic>> _tasks = [];
  bool _loading = true;
  String? _error;
  late String _filterStatus;
  String _filterProject = '';
  DateTime? _filterDateFrom;
  DateTime? _filterDateTo;

  @override
  void initState() {
    super.initState();
    _filterStatus = widget.initialStatus;
    NotificationService.instance.requestPermissions();
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
      if (!_matchesDueDateRange(t['dueDate'], _filterDateFrom, _filterDateTo)) {
        return false;
      }
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
    final total = statsTasks.length;
    final completed = statsTasks.where((t) => TaskStatus.normalize(t['status']) == 'Completed').length;
    final inProgress = statsTasks.where((t) => TaskStatus.normalize(t['status']) == 'In Progress').length;
    final pending = statsTasks.where((t) => TaskStatus.normalize(t['status']) == 'Pending').length;
    final overdue = statsTasks.where(TaskStatus.isDelayed).length;
    final urgent = statsTasks.where((t) {
      final p = (t['priority'] ?? '').toString().toLowerCase();
      return p == 'urgent' || p == 'high';
    }).length;
    final completionPct = total == 0 ? 0 : ((completed / total) * 100).round();

    final displayTasks = _filteredTasks;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: () => ApiCache.fresh(_load),
        child: Stack(
          children: [
            ListView(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 80 + MediaQuery.paddingOf(context).bottom),
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
                  inProgress: inProgress,
                  completed: completed,
                  completionPct: completionPct,
                  overdue: overdue,
                  urgent: urgent,
                  onSelectStatus: (status) => setState(() => _filterStatus = status),
                ),
                const SizedBox(height: 16),
                _FilterTabsRow(
                  activeStatus: _filterStatus,
                  onSelect: (status) => setState(() => _filterStatus = status),
                ),
                const SizedBox(height: 12),
                _FilterControlRow(
                  filterProject: _filterProject,
                  filterDateFrom: _filterDateFrom,
                  filterDateTo: _filterDateTo,
                  projects: _projectOptions,
                  onProjectChanged: (v) => setState(() => _filterProject = v),
                  onDateRangeChanged: (from, to) => setState(() {
                    _filterDateFrom = from;
                    _filterDateTo = to;
                  }),
                  onClearDates: () => setState(() {
                    _filterDateFrom = null;
                    _filterDateTo = null;
                  }),
                ),
                const SizedBox(height: 14),
                if (displayTasks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.assignment_outlined, size: 32, color: Color(0xFF94A3B8)),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _filterStatus == 'All' ? 'No tasks found' : 'No $_filterStatus tasks',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.isAllTasks
                                ? 'There are no tasks matching the selected filters.'
                                : 'You have no ${_filterStatus == 'All' ? '' : '$_filterStatus '}tasks assigned.',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
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
              bottom: 16 + MediaQuery.paddingOf(context).bottom,
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
    final oldStatus = TaskStatus.normalize(task['status']);
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

      final newStatus = TaskStatus.normalize(updated['status']);
      if (newStatus == 'Completed' && oldStatus != 'Completed') {
        final score = num.tryParse('${updated['rating']?['score']}')?.toInt() ?? 5;
        final feedback = TaskRatingFeedback.forScore(score);
        if (mounted) {
          showDialog<void>(
            context: context,
            builder: (_) => TaskRatingCelebrationDialog(
              task: updated,
              feedback: feedback,
            ),
          );
        }
      }
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
    this.onSelectStatus,
  });

  final int total;
  final int pending;
  final int inProgress;
  final int completed;
  final int completionPct;
  final int overdue;
  final int urgent;
  final ValueChanged<String>? onSelectStatus;

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
                onTap: () => onSelectStatus?.call('All'),
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
                onTap: () => onSelectStatus?.call('Completed'),
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
                onTap: () => onSelectStatus?.call('Delayed'),
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
                onTap: () => onSelectStatus?.call('All'),
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
    this.onTap,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final Color lineColor;
  final List<double> sparklineData;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
    ('Delayed', Icons.access_time_filled_rounded),
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

/// Filter Controls Row (Project Dropdown + Date Range Picker button).
class _FilterControlRow extends StatelessWidget {
  const _FilterControlRow({
    required this.filterProject,
    required this.filterDateFrom,
    required this.filterDateTo,
    required this.projects,
    required this.onProjectChanged,
    required this.onDateRangeChanged,
    required this.onClearDates,
  });

  final String filterProject;
  final DateTime? filterDateFrom;
  final DateTime? filterDateTo;
  final List<_ProjectOption> projects;
  final ValueChanged<String> onProjectChanged;
  final void Function(DateTime? from, DateTime? to) onDateRangeChanged;
  final VoidCallback onClearDates;

  @override
  Widget build(BuildContext context) {
    final hasDates = filterDateFrom != null || filterDateTo != null;
    final dateLabel = !hasDates
        ? 'Date Range'
        : (filterDateFrom != null && filterDateTo != null
            ? '${_ymd(filterDateFrom!)} - ${_ymd(filterDateTo!)}'
            : (filterDateFrom != null ? 'From ${_ymd(filterDateFrom!)}' : 'To ${_ymd(filterDateTo!)}'));

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
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
              initialDateRange: (filterDateFrom != null && filterDateTo != null)
                  ? DateTimeRange(start: filterDateFrom!, end: filterDateTo!)
                  : null,
            );
            if (picked != null) {
              onDateRangeChanged(picked.start, picked.end);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: hasDates ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: hasDates ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                ),
                const SizedBox(width: 4),
                Text(
                  dateLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: hasDates ? const Color(0xFF2563EB) : const Color(0xFF475569),
                  ),
                ),
                if (hasDates) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onClearDates,
                    child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF64748B)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Task Item Card component with complete description and metadata.
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
    final desc = (task['description'] ?? '').toString().trim();
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
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        desc,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (project.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        project,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF2563EB)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _BadgePill(
                          label: (task['pausedByBreak'] == true && status.toLowerCase() == 'paused')
                              ? 'Paused (On Break)'
                              : ((task['pausedByMeeting'] == true && status.toLowerCase() == 'paused')
                                  ? 'Paused (In Meeting)'
                                  : status),
                          bg: sBg,
                          fg: sFg,
                        ),
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
                  const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
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

String _assignedToName(Map<String, dynamic> t) {
  final a = t['assignedTo'];
  if (a is Map) return (a['name'] ?? a['title'] ?? '').toString();
  return (t['assignedToName'] ?? '').toString();
}

String _assignedByName(Map<String, dynamic> t) {
  final a = t['assignedBy'];
  if (a is Map) return (a['name'] ?? a['title'] ?? '').toString();
  return (t['assignedByName'] ?? '').toString();
}

bool _matchesDueDateRange(dynamic raw, DateTime? from, DateTime? to) {
  if (from == null && to == null) return true;
  if (raw == null) return false;
  final d = DateTime.tryParse('$raw');
  if (d == null) return false;
  final day = DateTime(d.year, d.month, d.day);
  if (from != null) {
    final fromDay = DateTime(from.year, from.month, from.day);
    if (day.isBefore(fromDay)) return false;
  }
  if (to != null) {
    final toDay = DateTime(to.year, to.month, to.day);
    if (day.isAfter(toDay)) return false;
  }
  return true;
}


String _ymd(DateTime d) => '${d.day}/${d.month}/${d.year}';

String _formatDateTime(dynamic raw) {
  if (raw == null) return '—';
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
  bool _isOnBreak = false;

  @override
  void initState() {
    super.initState();
    _task = Map<String, dynamic>.from(widget.task);
    _selectedStatus = TaskStatus.normalize(_task['status']);
    _isOnBreak = _task['pausedByBreak'] == true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkBreakStatus());
  }

  Future<void> _checkBreakStatus() async {
    final session = context.read<AuthSession>();
    final api = session.api;
    if (api == null || session.userId.isEmpty) return;
    try {
      final list = await api.fetchAttendanceToday(employeeId: session.userId);
      if (!mounted) return;
      final onBreak = list.any((a) => a['breakStartedAt'] != null && a['checkOut'] == null);
      if (onBreak != _isOnBreak) {
        setState(() => _isOnBreak = onBreak);
      }
    } catch (_) {}
  }

  Future<void> _updateStatus(String newStatus) async {
    if (newStatus == 'In Progress' && (_isOnBreak || _task['pausedByBreak'] == true)) {
      setState(() {
        _error = 'Cannot start or resume a task while on break. Please end your break first.';
      });
      return;
    }

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

      if (newStatus == 'Completed') {
        final score = num.tryParse('${updated['rating']?['score']}')?.toInt() ?? 5;
        final feedback = TaskRatingFeedback.forScore(score);
        await NotificationService.instance.show(
          id: id.hashCode,
          title: '$score ⭐ ${feedback.title}',
          body: feedback.message,
          channel: NotificationChannel.tasks,
        );
      }

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

  Widget _metaRow(String label, String value, {bool isLink = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isLink ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = (_task['title'] ?? 'Task Details').toString();
    final desc = (_task['description'] ?? '').toString().trim();
    final status = TaskStatus.normalize(_task['status']);
    final priority = (_task['priority'] ?? 'Normal').toString();
    final project = _projectName(_task);
    final assignedToName = _assignedToName(_task);
    final assignedByName = _assignedByName(_task);
    final duration = _task['estimatedDurationMinutes'];
    final referenceLink = _task['referenceLink']?.toString();
    final referenceUpload = _task['referenceUpload'] is Map ? _task['referenceUpload'] as Map : null;
    final (sBg, sFg) = TaskStatus.colors(status);
    final (pBg, pFg) = TaskStatus.priorityColors(priority);

    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
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
                  if (project.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _BadgePill(label: project, bg: const Color(0xFFEFF6FF), fg: const Color(0xFF2563EB)),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              const Text('Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: SelectableText(
                  desc.isNotEmpty ? desc : 'No description provided.',
                  style: TextStyle(
                    fontSize: 12,
                    color: desc.isNotEmpty ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                    fontStyle: desc.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Task Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    if (project.isNotEmpty)
                      _metaRow('Project', project),
                    if (assignedToName.isNotEmpty)
                      _metaRow('Assigned To', assignedToName),
                    if (assignedByName.isNotEmpty)
                      _metaRow('Assigned By', assignedByName),
                    if (_task['dueDate'] != null)
                      _metaRow('Due Date', _formatDateTime(_task['dueDate'])),
                    if (_task['createdAt'] != null)
                      _metaRow('Created', _formatDateTime(_task['createdAt'])),
                    if (duration != null && duration > 0)
                      _metaRow('Estimated Duration', '$duration mins'),
                    if (_task['platform'] != null)
                      _metaRow('Platform', '${_task['platform']}'),
                    if (_task['contentType'] != null)
                      _metaRow('Post Type', '${_task['contentType']}'),
                    if (referenceLink != null && referenceLink.isNotEmpty)
                      _metaRow('Reference Link', referenceLink, isLink: true),
                    if (referenceUpload != null && (referenceUpload['fileName'] != null || referenceUpload['name'] != null))
                      _metaRow('Attachment', '${referenceUpload['fileName'] ?? referenceUpload['name']}'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_isOnBreak || _task['pausedByBreak'] == true) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('☕', style: TextStyle(fontSize: 18)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Break in Progress',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF92400E),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'You cannot start or resume tasks until your break has ended. End your break from Attendance first.',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFB45309),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Text('Update Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['Pending', 'In Progress', 'Paused', 'Completed', 'Cancelled'].map((st) {
                  final isSel = _selectedStatus == st;
                  final isBlockedByBreak = st == 'In Progress' && (_isOnBreak || _task['pausedByBreak'] == true);
                  return ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isBlockedByBreak) ...[
                          const Icon(Icons.lock_outline_rounded, size: 12, color: Color(0xFFD97706)),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          st,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                            color: isSel
                                ? Colors.white
                                : (isBlockedByBreak ? const Color(0xFF94A3B8) : const Color(0xFF334155)),
                          ),
                        ),
                      ],
                    ),
                    selected: isSel,
                    selectedColor: const Color(0xFF2563EB),
                    backgroundColor: isBlockedByBreak ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
                    onSelected: _saving
                        ? null
                        : (_) {
                            if (isBlockedByBreak) {
                              setState(() {
                                _error = 'Cannot start or resume task while on break. End your break first.';
                              });
                              return;
                            }
                            _updateStatus(st);
                          },
                  );
                }).toList(),
              ),
              if (_saving) ...[
                const SizedBox(height: 10),
                const Row(
                  children: [
                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('Updating status...', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Encouraging messages model for ratings from 1 to 5.
class TaskRatingFeedback {
  final int score;
  final String title;
  final String message;

  const TaskRatingFeedback({
    required this.score,
    required this.title,
    required this.message,
  });

  static const Map<int, TaskRatingFeedback> all = {
    1: TaskRatingFeedback(
      score: 1,
      title: 'Needs Improvement',
      message: "Don't give up! Every challenge is an opportunity to learn and improve. Keep trying, and you'll get better.",
    ),
    2: TaskRatingFeedback(
      score: 2,
      title: 'Keep Going',
      message: "You're making progress! Stay focused, work on the little things, and keep moving forward.",
    ),
    3: TaskRatingFeedback(
      score: 3,
      title: 'Good Effort',
      message: "Good job! You're on the right track. Keep learning, stay consistent, and aim even higher.",
    ),
    4: TaskRatingFeedback(
      score: 4,
      title: 'Great Work',
      message: "Excellent effort! You're doing really well. Keep up the great work and push yourself toward excellence.",
    ),
    5: TaskRatingFeedback(
      score: 5,
      title: 'Outstanding Performance',
      message: "Fantastic work! You've done an amazing job. Keep shining, stay motivated, and continue setting new standards!",
    ),
  };

  static TaskRatingFeedback forScore(int? score) {
    final s = (score ?? 5).clamp(1, 5);
    return all[s] ?? all[5]!;
  }
}

/// Task completion celebration dialog with encouraging message and star rating.
class TaskRatingCelebrationDialog extends StatelessWidget {
  const TaskRatingCelebrationDialog({
    super.key,
    required this.task,
    required this.feedback,
  });

  final Map<String, dynamic> task;
  final TaskRatingFeedback feedback;

  @override
  Widget build(BuildContext context) {
    final title = (task['title'] ?? 'Task').toString();
    final score = feedback.score;
    final ratingComments = task['rating']?['comments']?.toString() ?? '';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Text('🏆', style: TextStyle(fontSize: 34)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final filled = index < score;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: filled ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                    size: 28,
                  ),
                );
              }),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$score / 5 Rating',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFB45309),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              feedback.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Text(
                    '“${feedback.message}”',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF334155),
                      height: 1.45,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (ratingComments.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      ratingComments,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF64748B),
                        height: 1.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Task: $title',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text(
                  'Great, Keep Going!',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
