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
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_error!, style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C))),
          const SizedBox(height: 8),
          TextButton(onPressed: _load, child: const Text('Retry', style: TextStyle(fontSize: 12))),
        ],
      );
    }

    final statsTasks = _tasksForStats;
    final total = statsTasks.length;
    final completed = statsTasks.where((t) => TaskStatus.normalize(t['status']) == 'Completed').length;
    final inProgress = statsTasks.where((t) => TaskStatus.normalize(t['status']) == 'In Progress').length;
    final pending = statsTasks.where((t) => TaskStatus.normalize(t['status']) == 'Pending').length;
    final overdue = statsTasks.where(TaskStatus.isDelayed).length;
    final urgent = statsTasks.where((t) => t['priority'] == 'Urgent').length;
    final completionPct = total == 0 ? 0 : ((completed / total) * 100).round();

    return RefreshIndicator(
      onRefresh: _load,
      child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 72),
            children: [
          Text(
            widget.isAllTasks
                ? 'Overview and status of all company tasks across all projects.'
                : 'Tasks assigned to you by project managers and team leads.',
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.35),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _StatCard(
                title: 'Total',
                value: '$total',
                subtitle: '$pending pending · $inProgress active',
                onTap: () => setState(() => _filterStatus = 'All'),
              ),
              _StatCard(
                title: 'Done',
                value: '$completed',
                subtitle: '$completionPct% complete',
                accent: const Color(0xFF059669),
                onTap: () => setState(() => _filterStatus = 'Completed'),
              ),
              _StatCard(
                title: 'Overdue',
                value: '$overdue',
                subtitle: 'Needs attention',
                accent: const Color(0xFFD97706),
                onTap: () => setState(() => _filterStatus = 'Delayed'),
              ),
              _StatCard(
                title: 'Urgent',
                value: '$urgent',
                subtitle: 'High priority',
                accent: const Color(0xFFDC2626),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _FiltersBar(
            filterStatus: _filterStatus,
            filterProject: _filterProject,
            filterDate: _filterDate,
            projects: _projectOptions,
            onStatusChanged: (v) => setState(() => _filterStatus = v),
            onProjectChanged: (v) => setState(() => _filterProject = v),
            onDateChanged: (v) => setState(() => _filterDate = v),
            onClear: () => setState(() {
              _filterStatus = 'All';
              _filterProject = '';
              _filterDate = null;
            }),
          ),
          const SizedBox(height: 8),
          if (_filteredTasks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text('No tasks match your filters', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              ),
            )
          else
            ..._filteredTasks.map((task) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _TaskTile(
                    task: task,
                    onTap: () => _openTaskDetail(task),
                  ),
                )),
            ],
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: FloatingActionButton.extended(
              onPressed: () => AppNavScope.navigate(context, '/assign-task-self'),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Task', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
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

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    this.accent,
    this.onTap,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color? accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final w = (MediaQuery.sizeOf(context).width - 26) / 2;
    return SizedBox(
      width: w,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(height: 2, color: accent ?? const Color(0xFF6366F1)),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                      const SizedBox(height: 2),
                      Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      Text(subtitle, style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.filterStatus,
    required this.filterProject,
    required this.filterDate,
    required this.projects,
    required this.onStatusChanged,
    required this.onProjectChanged,
    required this.onDateChanged,
    required this.onClear,
  });

  final String filterStatus;
  final String filterProject;
  final DateTime? filterDate;
  final List<_ProjectOption> projects;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onProjectChanged;
  final ValueChanged<DateTime?> onDateChanged;
  final VoidCallback onClear;

  static const _statuses = ['All', 'Pending', 'In Progress', 'Paused', 'Completed', 'Cancelled', 'Delayed'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 32,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _statuses.length,
            separatorBuilder: (context, _) => const SizedBox(width: 6),
            itemBuilder: (context, i) {
              final s = _statuses[i];
              final selected = filterStatus == s;
              return FilterChip(
                label: Text(s, style: TextStyle(fontSize: 10, color: selected ? Colors.white : const Color(0xFF475569))),
                selected: selected,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                selectedColor: const Color(0xFF2563EB),
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                showCheckmark: false,
                onSelected: (_) => onStatusChanged(s),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                isDense: true,
                initialValue: filterProject.isEmpty ? '' : filterProject,
                decoration: _filterDecoration('Project'),

                style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                items: [
                  const DropdownMenuItem(value: '', child: Text('All projects', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                  ...projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis))),
                ],
                onChanged: (v) => onProjectChanged(v ?? ''),
              ),
            ),
            const SizedBox(width: 6),
            OutlinedButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: filterDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                onDateChanged(picked);
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(72, 36),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                textStyle: const TextStyle(fontSize: 10),
              ),
              child: Text(filterDate == null ? 'Date' : _ymd(filterDate!)),
            ),
            if (filterStatus != 'All' || filterProject.isNotEmpty || filterDate != null)
              IconButton(
                iconSize: 18,
                onPressed: onClear,
                icon: const Icon(Icons.clear),
                tooltip: 'Clear filters',
              ),
          ],
        ),
      ],
    );
  }

  InputDecoration _filterDecoration(String hint) {
    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task, required this.onTap});
  final Map<String, dynamic> task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = TaskStatus.normalize(task['status']);
    final (sBg, sFg) = TaskStatus.colors(status);
    final priority = task['priority']?.toString();
    final (pBg, pFg) = TaskStatus.priorityColors(priority);
    final delayed = TaskStatus.isDelayed(task);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: delayed ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      (task['title'] ?? 'Task').toString(),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, height: 1.25),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (task['source'] == 'social_media')
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(4)),
                      child: const Text('Social', style: TextStyle(fontSize: 8, color: Color(0xFF4338CA), fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _projectName(task),
                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _Chip(label: status, bg: sBg, fg: sFg),
                  if (priority != null && priority.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    _Chip(label: priority, bg: pBg, fg: pFg),
                  ],
                  const Spacer(),
                  Text(
                    'Due ${_formatDateTime(task['dueDate'])}',
                    style: TextStyle(fontSize: 9, color: delayed ? const Color(0xFFDC2626) : const Color(0xFF94A3B8), fontWeight: delayed ? FontWeight.w600 : FontWeight.normal),
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

class _TaskDetailSheet extends StatefulWidget {
  const _TaskDetailSheet({required this.task});
  final Map<String, dynamic> task;

  @override
  State<_TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<_TaskDetailSheet> {
  late Map<String, dynamic> _task;
  bool _loading = false;
  bool _saving = false;
  String? _error;
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _task = Map<String, dynamic>.from(widget.task);
    _selectedStatus = TaskStatus.normalize(_task['status']);
    _refreshTask();
  }

  Future<void> _refreshTask() async {
    final id = _task['_id']?.toString();
    if (id == null || id.isEmpty) return;
    final api = context.read<AuthSession>().api;
    if (api == null) return;
    setState(() => _loading = true);
    try {
      final fresh = await api.fetchTaskById(id);
      if (!mounted) return;
      setState(() {
        _task = fresh;
        _selectedStatus = TaskStatus.normalize(_task['status']);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveStatus() async {
    final id = _task['_id']?.toString();
    final status = _selectedStatus;
    if (id == null || status == null) return;
    final api = context.read<AuthSession>().api;
    if (api == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await api.updateTask(id, {'status': status});
      if (!mounted) return;
      setState(() {
        _task = updated;
        _selectedStatus = TaskStatus.normalize(_task['status']);
        _saving = false;
      });
      Navigator.of(context).pop(_task);
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
    final options = TaskStatus.editableOptions(_task);
    final canEdit = options.length > 1;
    final rating = _task['rating'];
    final ratingScore = rating is Map ? rating['score'] : null;

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(width: 36, height: 4, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(999))),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        (_task['title'] ?? 'Task').toString(),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(iconSize: 20, onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                    : ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                        children: [
                          _DetailCard(
                            rows: [
                              _DetailRow('Project', _projectName(_task)),
                              _DetailRow('Priority', (_task['priority'] ?? '—').toString()),
                              _DetailRow('Due', _formatDateTime(_task['dueDate'])),
                              _DetailRow('Assigned', _formatDateTime(_task['createdAt'])),
                              _DetailRow('Updated', _formatDateTime(_task['updatedAt'])),
                              _DetailRow('Assigned by', _personName(_task['assignedBy'])),
                              if (ratingScore != null) _DetailRow('Rating', '$ratingScore / 5'),
                            ],
                          ),
                          if ((_task['description'] ?? '').toString().trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _DetailCard(
                              title: 'Description',
                              child: Text(
                                _task['description'].toString(),
                                style: const TextStyle(fontSize: 11, color: Color(0xFF334155), height: 1.35),
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          _DetailCard(
                            title: 'Update status',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedStatus,
                                  isDense: true,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  style: const TextStyle(fontSize: 11),
                                  items: options
                                      .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)))
                                      .toList(),
                                  onChanged: canEdit ? (v) => setState(() => _selectedStatus = v) : null,
                                ),
                                if (_error != null) ...[
                                  const SizedBox(height: 6),
                                  Text(_error!, style: const TextStyle(fontSize: 10, color: Color(0xFFB91C1C))),
                                ],
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 36,
                                  child: FilledButton(
                                    onPressed: !canEdit || _saving || _selectedStatus == TaskStatus.normalize(_task['status']) ? null : _saveStatus,
                                    style: FilledButton.styleFrom(textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                    child: _saving
                                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : const Text('Save status'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({this.title, this.rows = const [], this.child});
  final String? title;
  final List<_DetailRow> rows;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
          ],
          ?child,
          ...rows,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 88, child: Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 11, color: Color(0xFF334155)))),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.bg, required this.fg});
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

class _ProjectOption {
  const _ProjectOption({required this.id, required this.name});
  final String id;
  final String name;
}

String _projectId(Map<String, dynamic> task) {
  if (task['source'] == 'social_media') return 'social-media';
  final p = task['project'];
  if (p is Map) return (p['_id'] ?? p['id'] ?? '').toString();
  return p?.toString() ?? '';
}

String _projectName(Map<String, dynamic> task) {
  if (task['source'] == 'social_media') return 'Social Media';
  final p = task['project'];
  if (p is Map) return (p['projectName'] ?? p['name'] ?? 'Project').toString();
  return '—';
}

String _personName(dynamic v) {
  if (v is Map) return (v['name'] ?? '—').toString();
  return v?.toString() ?? '—';
}

String _formatDateTime(dynamic v) {
  if (v == null) return '—';
  final d = DateTime.tryParse(v.toString());
  if (d == null) return v.toString();
  return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

String _ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

bool _matchesDueDate(dynamic dueDateVal, DateTime filterDate) {
  if (dueDateVal == null) return false;
  final d = DateTime.tryParse(dueDateVal.toString());
  if (d == null) return false;
  return d.year == filterDate.year && d.month == filterDate.month && d.day == filterDate.day;
}
