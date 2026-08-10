import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_session.dart';
import '../auth/role_access.dart';
import '../utils/leave_helpers.dart';

enum _LeaveTab { my, list, calendar, settings }

/// `/leave` — apply, track, and approve leave (mirrors web `LeaveView.jsx`).
class LeavePage extends StatefulWidget {
  const LeavePage({super.key});

  @override
  State<LeavePage> createState() => _LeavePageState();
}

class _LeavePageState extends State<LeavePage> {
  List<Map<String, dynamic>> _leaves = [];
  bool _loading = true;
  String? _error;

  _LeaveTab _tab = _LeaveTab.my;
  String _searchQuery = '';
  String _filterLeaveType = '';
  String _filterStatus = '';
  late DateTime _dateFrom;
  late DateTime _dateTo;
  DateTime _calendarMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateFrom = LeaveHelpers.monthStart(now);
    _dateTo = LeaveHelpers.monthEnd(now);
    _calendarMonth = DateTime(now.year, now.month);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isApprover = RoleAccess.canApproveLeave(context.read<AuthSession>().user);
      if (isApprover) setState(() => _tab = _LeaveTab.list);
      _load(isApprover: isApprover);
    });
  }

  Future<void> _load({bool? isApprover}) async {
    final session = context.read<AuthSession>();
    final approver = isApprover ?? RoleAccess.canApproveLeave(session.user);
    final api = session.api;
    if (api == null) {
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
      final items = await api.fetchLeave(
        employeeId: approver ? null : session.userId,
      );
      if (!mounted) return;
      setState(() {
        _leaves = items;
        _loading = false;
        if (!approver) _tab = _LeaveTab.my;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _tabLeaves {
    final session = context.read<AuthSession>();
    if (_tab == _LeaveTab.my) {
      return _leaves.where((l) => LeaveHelpers.employeeIdFrom(l['employee']) == session.userId).toList();
    }
    return _leaves;
  }

  List<Map<String, dynamic>> _filteredLeavesFor({DateTime? rangeFrom, DateTime? rangeTo}) {
    final from = rangeFrom ?? _dateFrom;
    final to = rangeTo ?? _dateTo;
    final q = _searchQuery.trim().toLowerCase();
    return _tabLeaves.where((leave) {
      if (_filterLeaveType.isNotEmpty && leave['leaveType'] != _filterLeaveType) return false;
      if (_filterStatus.isNotEmpty && leave['status'] != _filterStatus) return false;
      if (!LeaveHelpers.leaveInDateRange(leave, from, to)) return false;
      if (q.isNotEmpty) {
        final name = LeaveHelpers.employeeNameFrom(leave['employee']).toLowerCase();
        final designation = LeaveHelpers.designationFrom(leave['employee']).toLowerCase();
        if (!name.contains(q) && !designation.contains(q)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) {
        final da = LeaveHelpers.parseDate(b['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final db = LeaveHelpers.parseDate(a['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return da.compareTo(db);
      });
  }

  List<Map<String, dynamic>> get _filteredLeaves => _filteredLeavesFor();

  List<Map<String, dynamic>> get _calendarLeaves {
    final from = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    final to = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0);
    return _filteredLeavesFor(rangeFrom: from, rangeTo: to);
  }

  ({int total, int approved, int pending, int rejected}) get _stats {
    final items = _tabLeaves;
    return (
      total: items.length,
      approved: items.where((l) => l['status'] == 'Approved').length,
      pending: items.where((l) => l['status'] == 'Pending').length,
      rejected: items.where((l) => l['status'] == 'Rejected').length,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    final session = context.watch<AuthSession>();
    final isApprover = RoleAccess.canApproveLeave(session.user);
    if (!isApprover && _tab == _LeaveTab.list) _tab = _LeaveTab.my;

    return RefreshIndicator(
      onRefresh: _load,
      child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 72),
            children: [
              Text(
                isApprover
                    ? 'Manage team leave requests and approvals.'
                    : 'Apply for leave and track your applications.',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.35),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Text(_error!, style: const TextStyle(fontSize: 11, color: Color(0xFFB91C1C))),
                ),
              ],
              const SizedBox(height: 8),
              _TabBar(
                isApprover: isApprover,
                tab: _tab,
                onChanged: (t) => setState(() => _tab = t),
              ),
              const SizedBox(height: 10),
              if (_tab == _LeaveTab.my || _tab == _LeaveTab.list) ...[
                _StatsGrid(stats: _stats),
                const SizedBox(height: 8),
                _FiltersPanel(
                  searchQuery: _searchQuery,
                  filterLeaveType: _filterLeaveType,
                  filterStatus: _filterStatus,
                  dateFrom: _dateFrom,
                  dateTo: _dateTo,
                  showSearch: isApprover && _tab == _LeaveTab.list,
                  onSearchChanged: (v) => setState(() => _searchQuery = v),
                  onLeaveTypeChanged: (v) => setState(() => _filterLeaveType = v),
                  onStatusChanged: (v) => setState(() => _filterStatus = v),
                  onDateFromChanged: (v) => setState(() => _dateFrom = v),
                  onDateToChanged: (v) => setState(() => _dateTo = v),
                  onClear: () => setState(() {
                    _searchQuery = '';
                    _filterLeaveType = '';
                    _filterStatus = '';
                    final now = DateTime.now();
                    _dateFrom = LeaveHelpers.monthStart(now);
                    _dateTo = LeaveHelpers.monthEnd(now);
                  }),
                ),
                const SizedBox(height: 8),
                if (_filteredLeaves.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text('No leave applications found', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    ),
                  )
                else
                  ..._filteredLeaves.map((leave) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _LeaveCard(
                          leave: leave,
                          showEmployee: isApprover && _tab == _LeaveTab.list,
                          canApprove: _canApproveLeave(session, leave),
                          onTap: () => _openDetail(leave),
                          onForward: () => _forwardLeave(leave),
                          onReject: () => _rejectLeave(leave),
                        ),
                      )),
              ] else if (_tab == _LeaveTab.calendar) ...[
                _CalendarPanel(
                  month: _calendarMonth,
                  leaves: _calendarLeaves,
                  onPrev: () => setState(() {
                    _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month - 1);
                  }),
                  onNext: () => setState(() {
                    _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month + 1);
                  }),
                ),
              ] else if (_tab == _LeaveTab.settings && isApprover) ...[
                const _LeaveSettingsPanel(),
              ],
            ],
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: FloatingActionButton.extended(
              onPressed: _openApplyForm,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Apply Leave', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  bool _canApproveLeave(AuthSession session, Map<String, dynamic> leave) {
    if (!RoleAccess.canApproveLeave(session.user)) return false;
    if (leave['status'] != 'Pending') return false;
    final role = RoleAccess.leaveApprovalRole(session.user);
    final stage = (leave['approvalStage'] ?? 'team_leader').toString();
    if (!RoleAccess.canActOnLeaveStage(role, stage)) return false;
    return LeaveHelpers.employeeIdFrom(leave['employee']) != session.userId;
  }

  Future<void> _openApplyForm() async {
    final session = context.read<AuthSession>();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ApplyLeaveSheet(employeeId: session.userId),
    );
    if (ok == true && mounted) _load();
  }

  Future<void> _openDetail(Map<String, dynamic> leave) async {
    final session = context.read<AuthSession>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LeaveDetailSheet(
        leave: leave,
        showEmployee: RoleAccess.canApproveLeave(session.user),
        canApprove: _canApproveLeave(session, leave),
        onForward: () async {
          Navigator.pop(context);
          await _forwardLeave(leave);
        },
        onReject: () async {
          Navigator.pop(context);
          await _rejectLeave(leave);
        },
      ),
    );
  }

  Future<void> _forwardLeave(Map<String, dynamic> leave) async {
    final session = context.read<AuthSession>();
    final api = session.api;
    final id = leave['_id']?.toString();
    if (api == null || id == null) return;
    try {
      await api.updateLeaveStatus(id, action: 'Forward', actorId: session.userId);
      if (mounted) _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _rejectLeave(Map<String, dynamic> leave) async {
    final session = context.read<AuthSession>();
    final api = session.api;
    final id = leave['_id']?.toString();
    if (api == null || id == null) return;

    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => _RejectDialog(),
    );
    if (reason == null || !mounted) return;

    try {
      await api.updateLeaveStatus(id, action: 'Reject', actorId: session.userId, comment: reason);
      if (mounted) _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.isApprover, required this.tab, required this.onChanged});
  final bool isApprover;
  final _LeaveTab tab;
  final ValueChanged<_LeaveTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final tabs = isApprover
        ? const [
            (_LeaveTab.list, 'Leave List'),
            (_LeaveTab.my, 'My Leave'),
            (_LeaveTab.calendar, 'Calendar'),
            (_LeaveTab.settings, 'Settings'),
          ]
        : const [
            (_LeaveTab.my, 'My Leave'),
            (_LeaveTab.calendar, 'Calendar'),
          ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((t) {
          final selected = tab == t.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(t.$2, style: TextStyle(fontSize: 10, fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
              selected: selected,
              onSelected: (_) => onChanged(t.$1),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});
  final ({int total, int approved, int pending, int rejected}) stats;

  String _pct(int n) => stats.total == 0 ? '0%' : '${((n / stats.total) * 100).toStringAsFixed(1)}%';

  @override
  Widget build(BuildContext context) {
    final w = (MediaQuery.sizeOf(context).width - 26) / 2;
    final cards = [
      ('Total', '${stats.total}', 'All time', const Color(0xFF2563EB)),
      ('Approved', '${stats.approved}', _pct(stats.approved), const Color(0xFF059669)),
      ('Pending', '${stats.pending}', _pct(stats.pending), const Color(0xFFD97706)),
      ('Rejected', '${stats.rejected}', _pct(stats.rejected), const Color(0xFFDC2626)),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: cards
          .map((c) => SizedBox(
                width: w,
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    color: Colors.white,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(height: 2, color: c.$4),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.$1, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                            Text(c.$2, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            Text(c.$3, style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _FiltersPanel extends StatelessWidget {
  const _FiltersPanel({
    required this.searchQuery,
    required this.filterLeaveType,
    required this.filterStatus,
    required this.dateFrom,
    required this.dateTo,
    required this.showSearch,
    required this.onSearchChanged,
    required this.onLeaveTypeChanged,
    required this.onStatusChanged,
    required this.onDateFromChanged,
    required this.onDateToChanged,
    required this.onClear,
  });

  final String searchQuery;
  final String filterLeaveType;
  final String filterStatus;
  final DateTime dateFrom;
  final DateTime dateTo;
  final bool showSearch;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onLeaveTypeChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<DateTime> onDateFromChanged;
  final ValueChanged<DateTime> onDateToChanged;
  final VoidCallback onClear;

  Future<void> _pickDate(BuildContext context, DateTime initial, ValueChanged<DateTime> onPick) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) onPick(picked);
  }

  @override
  Widget build(BuildContext context) {
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
          if (showSearch) ...[
            TextField(
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search employees…',
                hintStyle: const TextStyle(fontSize: 11),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
              style: const TextStyle(fontSize: 11),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(child: _FilterDropdown(
                label: 'Type',
                value: filterLeaveType,
                items: const ['', ...LeaveHelpers.leaveTypes],
                labelFor: (v) => v.isEmpty ? 'All' : LeaveHelpers.leaveTypeLabel(v),
                onChanged: onLeaveTypeChanged,
              )),
              const SizedBox(width: 6),
              Expanded(child: _FilterDropdown(
                label: 'Status',
                value: filterStatus,
                items: const ['', 'Pending', 'Approved', 'Rejected'],
                labelFor: (v) => v.isEmpty ? 'All' : v,
                onChanged: onStatusChanged,
              )),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _DateChip(
                  label: 'From',
                  value: LeaveHelpers.ymd(dateFrom),
                  onTap: () => _pickDate(context, dateFrom, onDateFromChanged),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _DateChip(
                  label: 'To',
                  value: LeaveHelpers.ymd(dateTo),
                  onTap: () => _pickDate(context, dateTo, onDateToChanged),
                ),
              ),
              const SizedBox(width: 6),
              TextButton(onPressed: onClear, child: const Text('Clear', style: TextStyle(fontSize: 10))),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.labelFor,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final String Function(String) labelFor;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        DropdownButtonFormField<String>(
          value: value.isEmpty ? '' : value,
          isDense: true,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          ),
          style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A)),
          items: items.map((v) => DropdownMenuItem(value: v, child: Text(labelFor(v), style: const TextStyle(fontSize: 11)))).toList(),
          onChanged: (v) => onChanged(v ?? ''),
        ),
      ],
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(value, style: const TextStyle(fontSize: 11)),
          ),
        ),
      ],
    );
  }
}

class _LeaveCard extends StatelessWidget {
  const _LeaveCard({
    required this.leave,
    required this.showEmployee,
    required this.canApprove,
    required this.onTap,
    required this.onForward,
    required this.onReject,
  });

  final Map<String, dynamic> leave;
  final bool showEmployee;
  final bool canApprove;
  final VoidCallback onTap;
  final VoidCallback onForward;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final status = leave['status']?.toString();
    final type = leave['leaveType']?.toString();
    final (typeBg, typeFg) = LeaveHelpers.leaveTypeColors(type);
    final (statusBg, statusFg) = LeaveHelpers.statusColors(status);

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
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showEmployee) ...[
                Text(
                  LeaveHelpers.employeeNameFrom(leave['employee']),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
                Text(
                  LeaveHelpers.designationFrom(leave['employee']),
                  style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 6),
              ],
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _Badge(text: LeaveHelpers.leaveTypeLabel(type), bg: typeBg, fg: typeFg),
                  _Badge(text: status ?? '—', bg: statusBg, fg: statusFg),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${LeaveHelpers.formatLeaveDate(leave['startDate'])} → ${LeaveHelpers.formatLeaveDate(leave['endDate'])}',
                style: const TextStyle(fontSize: 10, color: Color(0xFF475569)),
              ),
              Row(
                children: [
                  Text('${leave['numberOfDays'] ?? '—'} day(s)', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(
                    LeaveHelpers.stageLabel(leave['approvalStage']?.toString(), status: status ?? ''),
                    style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              if (leave['reason'] != null && '${leave['reason']}'.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '${leave['reason']}',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (canApprove) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onForward,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF047857),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                        child: const Text('Forward'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onReject,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFB91C1C),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                        child: const Text('Reject'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.bg, required this.fg});
  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

class _CalendarPanel extends StatelessWidget {
  const _CalendarPanel({
    required this.month,
    required this.leaves,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime month;
  final List<Map<String, dynamic>> leaves;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final startPad = firstDay.weekday % 7;
    final cells = <int?>[...List.filled(startPad, null), ...List.generate(daysInMonth, (i) => i + 1)];

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left, size: 20), padding: EdgeInsets.zero),
              Expanded(
                child: Text(
                  '${months[month.month - 1]} ${month.year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right, size: 20), padding: EdgeInsets.zero),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                .map((d) => Expanded(
                      child: Center(child: Text(d, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)))),
                    ))
                .toList(),
          ),
          const SizedBox(height: 4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 4, crossAxisSpacing: 4, childAspectRatio: 0.85),
            itemCount: cells.length,
            itemBuilder: (context, idx) {
              final day = cells[idx];
              if (day == null) return const SizedBox.shrink();
              final dayLeaves = leaves.where((l) => LeaveHelpers.isOnCalendarDay(l, month.year, month.month, day)).toList();
              return Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$day', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600)),
                    if (dayLeaves.isNotEmpty)
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: dayLeaves.take(2).map((l) {
                            final (bg, fg) = LeaveHelpers.statusColors(l['status']?.toString());
                            final name = LeaveHelpers.employeeNameFrom(l['employee']).split(' ').first;
                            return Container(
                              margin: const EdgeInsets.only(top: 1),
                              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(2)),
                              child: Text(name, style: TextStyle(fontSize: 7, color: fg), overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LeaveSettingsPanel extends StatelessWidget {
  const _LeaveSettingsPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Leave Settings', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Configured leave types for your organization.', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
          const SizedBox(height: 10),
          for (final type in LeaveHelpers.leaveTypes) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Builder(
                    builder: (context) {
                      final (bg, fg) = LeaveHelpers.leaveTypeColors(type);
                      return _Badge(text: LeaveHelpers.leaveTypeLabel(type), bg: bg, fg: fg);
                    },
                  ),
                  const Spacer(),
                  const Text('Enabled', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ApplyLeaveSheet extends StatefulWidget {
  const _ApplyLeaveSheet({required this.employeeId});
  final String employeeId;

  @override
  State<_ApplyLeaveSheet> createState() => _ApplyLeaveSheetState();
}

class _ApplyLeaveSheetState extends State<_ApplyLeaveSheet> {
  String _leaveType = 'Casual';
  DateTime? _startDate;
  DateTime? _endDate;
  final _reasonCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => isStart ? _startDate = picked : _endDate = picked);
  }

  Future<void> _submit() async {
    if (_startDate == null || _endDate == null) {
      setState(() => _error = 'Start date and end date are required');
      return;
    }
    if (_endDate!.isBefore(_startDate!)) {
      setState(() => _error = 'End date must be on or after start date');
      return;
    }

    final api = context.read<AuthSession>().api;
    if (api == null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await api.createLeave(
        employeeId: widget.employeeId,
        leaveType: _leaveType,
        startDate: LeaveHelpers.ymd(_startDate!),
        endDate: LeaveHelpers.ymd(_endDate!),
        reason: _reasonCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        margin: const EdgeInsets.only(top: 48),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(width: 36, height: 4, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 12),
              const Text('Apply for Leave', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(fontSize: 11, color: Color(0xFFB91C1C))),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _leaveType,
                decoration: const InputDecoration(labelText: 'Leave Type', isDense: true),
                style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                items: LeaveHelpers.leaveTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(LeaveHelpers.leaveTypeLabel(t), style: const TextStyle(fontSize: 12))))
                    .toList(),
                onChanged: (v) => setState(() => _leaveType = v ?? 'Casual'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _DateChip(
                      label: 'From',
                      value: _startDate == null ? 'Select' : LeaveHelpers.ymd(_startDate!),
                      onTap: () => _pickDate(true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DateChip(
                      label: 'To',
                      value: _endDate == null ? 'Select' : LeaveHelpers.ymd(_endDate!),
                      onTap: () => _pickDate(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _reasonCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  hintText: 'Brief reason for leave',
                  alignLabelWithHint: true,
                ),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: Text(_submitting ? 'Submitting…' : 'Submit', style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting ? null : () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(fontSize: 12)),
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

class _LeaveDetailSheet extends StatelessWidget {
  const _LeaveDetailSheet({
    required this.leave,
    required this.showEmployee,
    required this.canApprove,
    required this.onForward,
    required this.onReject,
  });

  final Map<String, dynamic> leave;
  final bool showEmployee;
  final bool canApprove;
  final VoidCallback onForward;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final status = leave['status']?.toString();
    final history = leave['approvalHistory'];
    return Container(
      margin: const EdgeInsets.only(top: 48),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Center(
              child: Container(width: 36, height: 4, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 12),
            const Text('Leave Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            if (showEmployee) _detailRow('Employee', LeaveHelpers.employeeNameFrom(leave['employee'])),
            _detailRow('Type', LeaveHelpers.leaveTypeLabel(leave['leaveType']?.toString())),
            _detailRow('Status', status ?? '—'),
            _detailRow('From', LeaveHelpers.formatLeaveDate(leave['startDate'])),
            _detailRow('To', LeaveHelpers.formatLeaveDate(leave['endDate'])),
            _detailRow('Days', '${leave['numberOfDays'] ?? '—'}'),
            _detailRow('Reason', '${leave['reason'] ?? '—'}'),
            _detailRow('Applied On', LeaveHelpers.formatAppliedOn(leave['createdAt'])),
            _detailRow(
              'Approval Stage',
              LeaveHelpers.stageLabel(leave['approvalStage']?.toString(), status: status ?? ''),
            ),
            if (history is List && history.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Approval History', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              for (final entry in history)
                if (entry is Map) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${entry['action'] ?? '—'}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        Text(
                          '${LeaveHelpers.stageLabel(entry['stage']?.toString(), status: 'Pending')} · ${entry['actorName'] ?? entry['actor']?['name'] ?? 'System'}',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                        ),
                        if (entry['comment'] != null && '${entry['comment']}'.isNotEmpty)
                          Text('${entry['comment']}', style: const TextStyle(fontSize: 10, color: Color(0xFF475569))),
                      ],
                    ),
                  ),
                ],
            ],
            if (canApprove) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: FilledButton(onPressed: onForward, child: const Text('Forward', style: TextStyle(fontSize: 12)))),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton(onPressed: onReject, child: const Text('Reject', style: TextStyle(fontSize: 12)))),
                ],
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Close', style: TextStyle(fontSize: 12))),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }
}

class _RejectDialog extends StatefulWidget {
  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject Leave', style: TextStyle(fontSize: 14)),
      content: TextField(
        controller: _ctrl,
        maxLines: 3,
        decoration: const InputDecoration(hintText: 'Rejection reason (optional)', hintStyle: TextStyle(fontSize: 11)),
        style: const TextStyle(fontSize: 12),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(fontSize: 12))),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
          child: const Text('Confirm', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}
