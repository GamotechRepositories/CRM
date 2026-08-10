import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_session.dart';
import '../navigation/app_nav.dart';

/// `/assign-task` — create or assign a task (mirrors web `AssignTask.jsx`).
class AssignTaskPage extends StatefulWidget {
  const AssignTaskPage({super.key, this.selfMode = false});

  /// When true: assign to self + load `/projects/my-projects` only.
  final bool selfMode;

  @override
  State<AssignTaskPage> createState() => _AssignTaskPageState();
}

class _AssignTaskPageState extends State<AssignTaskPage> {
  static const _priorities = ['Low', 'Medium', 'High', 'Urgent'];
  static const _durations = [15, 30, 45, 60, 90, 120, 180, 240];
  static const _recurrenceTypes = [
    ('daily', 'Day(s)'),
    ('weekly', 'Week(s)'),
    ('monthly', 'Month(s)'),
  ];

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _intervalCtrl = TextEditingController(text: '1');

  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _employees = [];
  Map<String, Map<String, dynamic>> _availability = {};

  String? _projectId;
  String? _assigneeId;
  String _priority = 'Medium';
  DateTime? _dueDate;
  TimeOfDay? _startTime;
  int? _durationMinutes;
  bool _recurring = false;
  String _recurrenceType = 'daily';
  DateTime? _recurrenceEnd;

  bool _loadingData = true;
  bool _loadingAvailability = false;
  bool _submitting = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _dueDate = DateTime.now();
    _startTime = const TimeOfDay(hour: 9, minute: 0);
    _durationMinutes = 30;
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _intervalCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final session = context.read<AuthSession>();
    final api = session.api;
    if (api == null) {
      setState(() {
        _loadingData = false;
        _error = 'Not signed in';
      });
      return;
    }

    setState(() {
      _loadingData = true;
      _error = null;
    });

    try {
      final projectsFuture = widget.selfMode
          ? api.fetchMyProjects(session.userId)
          : api.fetchProjects();
      final employeesFuture = widget.selfMode ? Future.value(<Map<String, dynamic>>[]) : api.fetchEmployees();
      final results = await Future.wait([projectsFuture, employeesFuture]);
      if (!mounted) return;
      setState(() {
        _projects = results[0];
        _employees = results[1];
        _assigneeId = widget.selfMode ? session.userId : _assigneeId;
        _loadingData = false;
      });
      await _loadAvailability();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loadingData = false;
      });
    }
  }

  String get _scheduleDate => _ymd(_dueDate ?? DateTime.now());

  Future<void> _loadAvailability() async {
    final api = context.read<AuthSession>().api;
    if (api == null) return;
    setState(() => _loadingAvailability = true);
    try {
      final list = await api.fetchEmployeesAvailability(date: _scheduleDate);
      if (!mounted) return;
      final map = <String, Map<String, dynamic>>{};
      for (final item in list) {
        final id = (item['employeeId'] ?? item['_id'])?.toString();
        if (id != null && id.isNotEmpty) map[id] = item;
      }
      setState(() {
        _availability = map;
        _loadingAvailability = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingAvailability = false);
    }
  }

  Future<void> _submit() async {
    final session = context.read<AuthSession>();
    final api = session.api;
    final userId = session.userId;
    if (api == null || userId.isEmpty) {
      setState(() => _error = 'You must be logged in');
      return;
    }

    final title = _titleCtrl.text.trim();
    final assignee = widget.selfMode ? userId : _assigneeId;
    if (_projectId == null || _projectId!.isEmpty || title.isEmpty || assignee == null || assignee.isEmpty) {
      setState(() => _error = 'Project, title, and assignee are required');
      return;
    }
    if (_durationMinutes == null || _durationMinutes! <= 0) {
      setState(() => _error = 'Select task duration');
      return;
    }
    if (_startTime == null) {
      setState(() => _error = 'Select start time');
      return;
    }

    final avail = _availability[assignee];
    if (avail != null && avail['isAssignable'] == false) {
      setState(() => _error = '${avail['name'] ?? 'Employee'} is not available today');
      return;
    }

    final scheduledStartAt = _buildScheduledStartAt(_scheduleDate, _startTime!);
    if (scheduledStartAt == null) {
      setState(() => _error = 'Invalid schedule date/time');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _success = null;
    });

    try {
      final payload = <String, dynamic>{
        'project': _projectId,
        'title': title,
        'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'assignedTo': assignee,
        'assignedToList': [assignee],
        'assignedBy': userId,
        'priority': _priority,
        'dueDate': _scheduleDate,
        'scheduledStartAt': scheduledStartAt,
        'estimatedDurationMinutes': _durationMinutes,
        'isRecurring': _recurring,
        'recurrenceEnabled': _recurring,
      };
      if (_recurring) {
        payload['recurrenceType'] = _recurrenceType;
        payload['recurrenceInterval'] = int.tryParse(_intervalCtrl.text.trim()) ?? 1;
        payload['recurrenceStartDate'] = _scheduleDate;
        if (_recurrenceEnd != null) payload['recurrenceEndDate'] = _ymd(_recurrenceEnd!);
      }

      await api.createTask(payload);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _success = widget.selfMode ? 'Task created successfully.' : 'Task assigned successfully.';
        _titleCtrl.clear();
        _descCtrl.clear();
        if (!widget.selfMode) _assigneeId = null;
        _durationMinutes = 30;
        _startTime = const TimeOfDay(hour: 9, minute: 0);
        _recurring = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingData) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 24),
      children: [
        Text(
          widget.selfMode ? 'Create My Task' : 'Assign Task',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        Text(
          widget.selfMode
              ? 'Create and schedule your own task on a project you belong to.'
              : 'Assign a task with duration and schedule for an employee.',
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.35),
        ),
        const SizedBox(height: 10),
        _field(
          label: 'Project *',
          child: DropdownButtonFormField<String>(
            initialValue: _projectId?.isNotEmpty == true ? _projectId : null,
            decoration: _inputDecoration('Select project'),
            style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
            items: _projects
                .map((p) {
                  final id = (p['_id'] ?? p['id']).toString();
                  final name = (p['projectName'] ?? p['name'] ?? 'Project').toString();
                  final client = p['client'];
                  final clientName = client is Map ? (client['clientName'] ?? '') : '';
                  return DropdownMenuItem(
                    value: id,
                    child: Text(
                      clientName.toString().isEmpty ? name : '$name ($clientName)',
                      style: const TextStyle(fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                })
                .toList(),
            onChanged: (v) => setState(() => _projectId = v),
          ),
        ),
        _field(
          label: 'Task title *',
          child: TextField(
            controller: _titleCtrl,
            style: const TextStyle(fontSize: 12),
            decoration: _inputDecoration('Enter task title'),
          ),
        ),
        _field(
          label: 'Description',
          child: TextField(
            controller: _descCtrl,
            maxLines: 3,
            style: const TextStyle(fontSize: 12),
            decoration: _inputDecoration('Task description…'),
          ),
        ),
        if (!widget.selfMode) _buildAssigneeField(),
        if (widget.selfMode)
          _field(
            label: 'Assignee',
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                context.watch<AuthSession>().userName.isEmpty ? 'You' : context.watch<AuthSession>().userName,
                style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: _field(
                label: 'Priority',
                child: DropdownButtonFormField<String>(
                  initialValue: _priority,
                  decoration: _inputDecoration(null),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                  items: _priorities.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 11)))).toList(),
                  onChanged: (v) => setState(() => _priority = v ?? 'Medium'),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _field(
                label: 'Due date',
                child: OutlinedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dueDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() => _dueDate = picked);
                      await _loadAvailability();
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(40),
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                  child: Text(_ymd(_dueDate ?? DateTime.now())),
                ),
              ),
            ),
          ],
        ),
        _field(
          label: 'Schedule *',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _startTime ?? const TimeOfDay(hour: 9, minute: 0),
                        );
                        if (picked != null) setState(() => _startTime = picked);
                      },
                      icon: const Icon(Icons.schedule, size: 14),
                      label: Text(
                        _startTime == null ? 'Start time' : _startTime!.format(context),
                        style: const TextStyle(fontSize: 11),
                      ),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(40)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _durationMinutes,
                      decoration: _inputDecoration('Duration'),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                      items: _durations
                          .map((m) => DropdownMenuItem(value: m, child: Text(_formatDuration(m), style: const TextStyle(fontSize: 11))))
                          .toList(),
                      onChanged: (v) => setState(() => _durationMinutes = v),
                    ),
                  ),
                ],
              ),
              if (_loadingAvailability)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Checking availability…', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                  ),
                ),
            ],
          ),
        ),
        _buildRecurringSection(),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(fontSize: 11, color: Color(0xFFB91C1C))),
        ],
        if (_success != null) ...[
          const SizedBox(height: 8),
          Text(_success!, style: const TextStyle(fontSize: 11, color: Color(0xFF047857))),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 38,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  child: _submitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(widget.selfMode ? 'Create Task' : 'Assign Task'),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => AppNavScope.navigate(context, '/my-tasks'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(72, 38), textStyle: const TextStyle(fontSize: 11)),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAssigneeField() {
    return _field(
      label: 'Assign to *',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _assigneeId?.isNotEmpty == true ? _assigneeId : null,
            decoration: _inputDecoration('Select employee'),
            style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
            items: _employees.map((emp) {
              final id = (emp['_id'] ?? emp['id']).toString();
              final avail = _availability[id];
              final unavailable = avail?['isAssignable'] == false;
              final name = (emp['name'] ?? 'Employee').toString();
              final designation = emp['designation'];
              final title = designation is Map ? (designation['title'] ?? '') : '';
              final suffix = avail != null ? ' · ${avail['availabilityLabel'] ?? ''}' : '';
              return DropdownMenuItem(
                value: id,
                enabled: !unavailable,
                child: Text(
                  '$name${title.toString().isEmpty ? '' : ' ($title)'}${unavailable ? ' [Unavailable]' : suffix}',
                  style: const TextStyle(fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (v) => setState(() => _assigneeId = v),
          ),
          if (_assigneeId != null && _availability[_assigneeId!] != null) ...[
            const SizedBox(height: 6),
            _AvailabilityCard(data: _availability[_assigneeId!]!),
          ],
        ],
      ),
    );
  }

  Widget _buildRecurringSection() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
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
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Auto Task', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    Text('Create a recurring task automatically', style: TextStyle(fontSize: 9, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _recurring,
                onChanged: (v) => setState(() => _recurring = v),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
          if (_recurring) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 64,
                  child: TextField(
                    controller: _intervalCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 11),
                    decoration: _inputDecoration('Every'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _recurrenceType,
                    decoration: _inputDecoration(null),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                    items: _recurrenceTypes
                        .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2, style: const TextStyle(fontSize: 11))))
                        .toList(),
                    onChanged: (v) => setState(() => _recurrenceType = v ?? 'daily'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _recurrenceEnd ?? (_dueDate ?? DateTime.now()).add(const Duration(days: 30)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _recurrenceEnd = picked);
              },
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(36), textStyle: const TextStyle(fontSize: 10)),
              child: Text(_recurrenceEnd == null ? 'End date (optional)' : 'Ends ${_ymd(_recurrenceEnd!)}'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _field({required String label, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String? hint) {
    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.2)),
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final assignable = data['isAssignable'] != false;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: assignable ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: assignable ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${data['name'] ?? 'Employee'} · ${data['availabilityLabel'] ?? '—'}',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: assignable ? const Color(0xFF047857) : const Color(0xFFB91C1C)),
          ),
          Text(
            'Working hours: ${data['workingHours'] ?? '—'} · Open tasks: ${data['openTaskCount'] ?? 0}',
            style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String? _buildScheduledStartAt(String dateStr, TimeOfDay start) {
  final parts = dateStr.split('-');
  if (parts.length != 3) return null;
  final dt = DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
    start.hour,
    start.minute,
  );
  return dt.toIso8601String();
}

String _formatDuration(int minutes) {
  if (minutes >= 60) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
  return '${minutes}m';
}
