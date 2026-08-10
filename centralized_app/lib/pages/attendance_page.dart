import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../auth/auth_session.dart';
import '../auth/role_access.dart';
import '../utils/attendance_helpers.dart';

enum _ViewMode { live, monthly }

/// `/attendance` and `/my-attendance` — mirrors web `AttendanceView.jsx`.
class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key, this.forceSelfMode = false});

  /// When true, always show only the logged-in employee's attendance.
  final bool forceSelfMode;

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  _ViewMode _viewMode = _ViewMode.live;
  String _selectedDate = AttendanceHelpers.todayKey();
  String _selectedMonth = AttendanceHelpers.monthKey();
  String _searchQuery = '';
  String _selectedEmployeeId = '';

  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _dayAttendances = [];
  List<Map<String, dynamic>> _monthAttendances = [];
  List<Map<String, dynamic>> _leaves = [];

  bool _loading = true;
  bool _monthLoading = false;
  bool _actionLoading = false;
  String? _error;
  DateTime _liveClock = DateTime.now();
  Timer? _clockTimer;

  Position? _currentPosition;
  String? _locationError;
  bool _refreshingLocation = false;

  bool get _canViewTeam {
    if (widget.forceSelfMode) return false;
    return RoleAccess.canViewTeamAttendance(context.read<AuthSession>().user);
  }

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _liveClock = DateTime.now());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final session = context.read<AuthSession>();
      _selectedEmployeeId = session.userId;
      if (_canViewTeam) setState(() => _viewMode = _ViewMode.monthly);
      await _bootstrap();
      _refreshLocation(silent: true);
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await Future.wait([_loadEmployees(), _loadLeaves(), _loadDayAttendance(), _loadMonthAttendance()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadEmployees() async {
    final session = context.read<AuthSession>();
    final api = session.api;
    if (api == null) return;
    try {
      if (_canViewTeam) {
        final list = await api.fetchEmployees();
        if (!mounted) return;
        setState(() {
          _employees = list.where((e) => (e['employmentStatus'] ?? e['status'] ?? 'Active') == 'Active').toList();
        });
      } else {
        final emp = await api.fetchEmployeeById(session.userId);
        if (!mounted) return;
        final user = session.user ?? {};
        setState(() {
          _employees = [
            emp ??
                {
                  '_id': session.userId,
                  'name': session.userName,
                  'email': session.userEmail,
                  'profilePhoto': user['profilePhoto'],
                },
          ];
        });
      }
    } catch (_) {
      if (!mounted) return;
      final user = session.user ?? {};
      setState(() {
        _employees = [
          {
            '_id': session.userId,
            'name': session.userName,
            'email': session.userEmail,
            'profilePhoto': user['profilePhoto'],
          },
        ];
      });
    }
  }

  Future<void> _loadLeaves() async {
    final session = context.read<AuthSession>();
    final api = session.api;
    if (api == null) return;
    final items = await api.fetchLeave(employeeId: _canViewTeam ? null : session.userId);
    if (mounted) setState(() => _leaves = items);
  }

  Future<void> _loadDayAttendance() async {
    final session = context.read<AuthSession>();
    final api = session.api;
    if (api == null) return;
    final items = await api.fetchAttendanceToday(
      date: _selectedDate,
      employeeId: _canViewTeam ? null : session.userId,
    );
    if (mounted) setState(() => _dayAttendances = items);
  }

  Future<void> _loadMonthAttendance() async {
    final session = context.read<AuthSession>();
    final api = session.api;
    if (api == null) return;
    final targetId = _monthlyEmployeeId;
    if (targetId.isEmpty) return;
    setState(() => _monthLoading = true);
    try {
      final items = await api.fetchAttendanceByMonth(month: _selectedMonth, employeeId: targetId);
      if (mounted) setState(() => _monthAttendances = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _monthLoading = false);
    }
  }

  String get _monthlyEmployeeId {
    final session = context.read<AuthSession>();
    if (!_canViewTeam) return session.userId;
    return _selectedEmployeeId.isEmpty ? session.userId : _selectedEmployeeId;
  }

  Map<String, dynamic>? get _selectedMonthlyEmployee {
    final id = _monthlyEmployeeId;
    for (final e in _employees) {
      if ('${e['_id']}' == id) return e;
    }
    final session = context.read<AuthSession>();
    final user = session.user ?? {};
    return {
      '_id': id,
      'name': session.userName,
      'email': session.userEmail,
      'employeeCode': user['employeeCode'],
      'profilePhoto': user['profilePhoto'],
    };
  }

  Map<String, Map<String, dynamic>> get _monthAttendanceByDate => AttendanceHelpers.indexByDate(_monthAttendances);

  Map<String, dynamic>? get _myDayAttendance {
    final session = context.read<AuthSession>();
    for (final a in _dayAttendances) {
      if (AttendanceHelpers.employeeIdFrom(a['employee']) == session.userId) return a;
    }
    return null;
  }

  bool get _isToday => _selectedDate == AttendanceHelpers.todayKey();

  bool get _hasCheckedInToday => _myDayAttendance?['checkIn'] != null;

  bool get _hasCheckedOutToday => _myDayAttendance?['checkOut'] != null;

  bool get _isSessionActive => _isToday && _hasCheckedInToday && !_hasCheckedOutToday;

  bool get _canCheckIn => _isToday && !_hasCheckedInToday;

  bool get _canCheckOut => _isSessionActive;

  bool get _isBreakActive => _myDayAttendance?['breakStartedAt'] != null && !_hasCheckedOutToday;

  bool get _isMeetingActive => _myDayAttendance?['meetingStartedAt'] != null && !_hasCheckedOutToday;

  Future<void> _refreshLocation({bool silent = false}) async {
    if (!silent) setState(() => _refreshingLocation = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _locationError = 'Location permission denied';
            _refreshingLocation = false;
          });
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium));
      if (mounted) {
        setState(() {
          _currentPosition = pos;
          _locationError = null;
          _refreshingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationError = 'Unable to get location';
          _refreshingLocation = false;
        });
      }
    }
  }

  Future<({double lat, double lon, String address})?> _requireLocation() async {
    await _refreshLocation(silent: true);
    final pos = _currentPosition;
    if (pos == null) {
      setState(() => _error = _locationError ?? 'Location unavailable. Enable GPS and try again.');
      return null;
    }
    final address = AttendanceHelpers.formatCoords(pos.latitude, pos.longitude);
    return (lat: pos.latitude, lon: pos.longitude, address: address);
  }

  Future<void> _checkIn() async {
    final session = context.read<AuthSession>();
    final api = session.api;
    if (api == null || session.userId.isEmpty) return;
    final loc = await _requireLocation();
    if (loc == null) return;

    setState(() {
      _actionLoading = true;
      _error = null;
    });
    try {
      await api.checkIn(
        employeeId: session.userId,
        latitude: loc.lat,
        longitude: loc.lon,
        address: loc.address,
      );
      await _loadDayAttendance();
      await _loadMonthAttendance();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _checkOut() async {
    final session = context.read<AuthSession>();
    final api = session.api;
    if (api == null || session.userId.isEmpty) return;
    final loc = await _requireLocation();
    if (loc == null) return;

    setState(() {
      _actionLoading = true;
      _error = null;
    });
    try {
      await api.checkOut(
        employeeId: session.userId,
        latitude: loc.lat,
        longitude: loc.lon,
        address: loc.address,
      );
      await _loadDayAttendance();
      await _loadMonthAttendance();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _toggleBreak() async {
    final session = context.read<AuthSession>();
    final api = session.api;
    if (api == null) return;
    setState(() {
      _actionLoading = true;
      _error = null;
    });
    try {
      if (_isBreakActive) {
        await api.endBreak(employeeId: session.userId);
      } else {
        await api.startBreak(employeeId: session.userId);
      }
      await _loadDayAttendance();
      await _loadMonthAttendance();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _toggleMeeting() async {
    final session = context.read<AuthSession>();
    final api = session.api;
    if (api == null) return;
    setState(() {
      _actionLoading = true;
      _error = null;
    });
    try {
      if (_isMeetingActive) {
        await api.endMeeting(employeeId: session.userId);
      } else {
        await api.startMeeting(employeeId: session.userId);
      }
      await _loadDayAttendance();
      await _loadMonthAttendance();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  List<({Map<String, dynamic> emp, Map<String, dynamic>? att, String status})> get _liveRows {
    final session = context.read<AuthSession>();
    final base = _canViewTeam
        ? _employees
        : _employees.where((e) => '${e['_id']}' == session.userId);
    final attMap = <String, Map<String, dynamic>>{};
    for (final a in _dayAttendances) {
      attMap[AttendanceHelpers.employeeIdFrom(a['employee'])] = a;
    }
    return base.map((emp) {
      final id = '${emp['_id']}';
      final att = attMap[id];
      final onLeave = AttendanceHelpers.isOnLeave(_leaves, id, _selectedDate);
      return (
        emp: emp,
        att: att,
        status: AttendanceHelpers.deriveLiveStatus(att, onLeave),
      );
    }).toList();
  }

  List<({Map<String, dynamic> emp, Map<String, dynamic>? att, String status})> get _filteredLiveRows {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _liveRows;
    return _liveRows.where((r) {
      final name = AttendanceHelpers.employeeNameFrom(r.emp).toLowerCase();
      final email = '${r.emp['email'] ?? ''}'.toLowerCase();
      return name.contains(q) || email.contains(q);
    }).toList();
  }

  ({int present, int late, int absent, int onLeave}) get _dayStats {
    final rows = _liveRows;
    return (
      present: rows.where((r) => r.status == 'Present').length,
      late: rows.where((r) => r.status == 'Late').length,
      absent: rows.where((r) => r.status == 'Absent').length,
      onLeave: rows.where((r) => r.status == 'On Leave').length,
    );
  }

  List<({String dateKey, Map<String, dynamic>? att, String status, bool isFuture})> get _monthRows {
    final empId = _monthlyEmployeeId;
    if (empId.isEmpty || _selectedMonth.isEmpty) return [];
    final today = AttendanceHelpers.todayKey();
    final byDate = _monthAttendanceByDate;
    return AttendanceHelpers.daysInMonth(_selectedMonth).map((dateKey) {
      final att = byDate[dateKey];
      final onLeave = AttendanceHelpers.isOnLeave(_leaves, empId, dateKey);
      final isFuture = dateKey.compareTo(today) > 0;
      final status = isFuture ? '—' : AttendanceHelpers.deriveLiveStatus(att, onLeave);
      return (dateKey: dateKey, att: att, status: status, isFuture: isFuture);
    }).toList();
  }

  ({int present, int late, int absent, int onLeave, double totalHours}) get _monthStats {
    final rows = _monthRows.where((r) => !r.isFuture);
    return (
      present: rows.where((r) => r.status == 'Present').length,
      late: rows.where((r) => r.status == 'Late').length,
      absent: rows.where((r) => r.status == 'Absent').length,
      onLeave: rows.where((r) => r.status == 'On Leave').length,
      totalHours: rows.fold<double>(0, (s, r) => s + AttendanceHelpers.hoursFromRow(r.att, _liveClock)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    final session = context.watch<AuthSession>();
    final myAtt = _myDayAttendance;
    final netMs = AttendanceHelpers.durationMs(myAtt, _liveClock);
    final breakMinutes = AttendanceHelpers.trackedMinutes(myAtt, 'breakStartedAt', 'breakDurationMinutes', _liveClock);
    final meetingMinutes = AttendanceHelpers.trackedMinutes(myAtt, 'meetingStartedAt', 'meetingDurationMinutes', _liveClock);

    return RefreshIndicator(
      onRefresh: _bootstrap,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 20),
        children: [
          Text(
            _canViewTeam ? 'Attendance Dashboard' : 'My Attendance',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          Text(
            _viewMode == _ViewMode.monthly
                ? (_canViewTeam
                    ? 'Monthly attendance overview for selected employee'
                    : 'Your monthly check-in history and hours')
                : (_canViewTeam
                    ? 'Overview of team attendance and real-time status'
                    : 'Track your check-in, check-out, and daily attendance'),
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
          Row(
            children: [
              Expanded(
                child: SegmentedButton<_ViewMode>(
                  segments: const [
                    ButtonSegment(value: _ViewMode.live, label: Text('Live', style: TextStyle(fontSize: 10))),
                    ButtonSegment(value: _ViewMode.monthly, label: Text('Monthly', style: TextStyle(fontSize: 10))),
                  ],
                  selected: {_viewMode},
                  onSelectionChanged: (s) async {
                    setState(() => _viewMode = s.first);
                    if (s.first == _ViewMode.monthly) await _loadMonthAttendance();
                  },
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_viewMode == _ViewMode.live) ...[
            _CheckInPanel(
              liveClock: _liveClock,
              selectedDate: _selectedDate,
              isToday: _isToday,
              isSessionActive: _isSessionActive,
              hasCheckedOut: _hasCheckedOutToday,
              canCheckIn: _canCheckIn,
              canCheckOut: _canCheckOut,
              isBreakActive: _isBreakActive,
              isMeetingActive: _isMeetingActive,
              actionLoading: _actionLoading,
              netDuration: AttendanceHelpers.formatDurationMs(netMs),
              breakDuration: AttendanceHelpers.formatDurationMs((breakMinutes * 60000).round()),
              meetingDuration: AttendanceHelpers.formatDurationMs((meetingMinutes * 60000).round()),
              workingHours: netMs == null ? '0.0' : (netMs / 3600000).toStringAsFixed(1),
              breakHours: (breakMinutes / 60).toStringAsFixed(1),
              meetingHours: (meetingMinutes / 60).toStringAsFixed(1),
              locationLabel: _currentPosition == null
                  ? (_locationError ?? 'Detecting location…')
                  : AttendanceHelpers.formatCoords(_currentPosition!.latitude, _currentPosition!.longitude),
              refreshingLocation: _refreshingLocation,
              onRefreshLocation: () => _refreshLocation(),
              onCheckIn: _checkIn,
              onCheckOut: _checkOut,
              onToggleBreak: _toggleBreak,
              onToggleMeeting: _toggleMeeting,
              myAttendance: myAtt,
              myStatus: AttendanceHelpers.deriveLiveStatus(
                myAtt,
                AttendanceHelpers.isOnLeave(_leaves, session.userId, _selectedDate),
              ),
              userName: session.userName,
              userEmail: session.userEmail,
              photoUrl: AttendanceHelpers.profilePhotoUrl(
                _selectedMonthlyEmployee,
                apiBaseUrl: session.company?.apiBaseUrl,
              ),
            ),
            const SizedBox(height: 8),
            _DatePickerRow(
              date: _selectedDate,
              maxDate: AttendanceHelpers.todayKey(),
              onChanged: (d) async {
                setState(() => _selectedDate = d);
                await _loadDayAttendance();
              },
              onToday: () async {
                setState(() => _selectedDate = AttendanceHelpers.todayKey());
                await _loadDayAttendance();
              },
            ),
            if (_canViewTeam) ...[
              const SizedBox(height: 8),
              _StatsGrid(
                items: [
                  ('Present', '${_dayStats.present}', const Color(0xFF059669)),
                  ('Late', '${_dayStats.late}', const Color(0xFFD97706)),
                  ('Absent', '${_dayStats.absent}', const Color(0xFFDC2626)),
                  ('On Leave', '${_dayStats.onLeave}', const Color(0xFF7C3AED)),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search employee…',
                  hintStyle: const TextStyle(fontSize: 11),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                ),
                style: const TextStyle(fontSize: 11),
              ),
              const SizedBox(height: 8),
            ],
            if (!_canViewTeam) ...[
              const SizedBox(height: 8),
              _MyDayRecordCard(
                attendance: myAtt,
                status: AttendanceHelpers.deriveLiveStatus(
                  myAtt,
                  AttendanceHelpers.isOnLeave(_leaves, session.userId, _selectedDate),
                ),
                liveClock: _liveClock,
                dateLabel: AttendanceHelpers.formatDateLabel(_selectedDate),
              ),
            ] else ...[
              if (_filteredLiveRows.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('No attendance records', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
                )
              else
                ..._filteredLiveRows.map((row) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _TeamAttendanceCard(
                        row: row,
                        liveClock: _liveClock,
                        apiBaseUrl: session.company?.apiBaseUrl,
                      ),
                    )),
            ],
          ] else ...[
            _MonthlyEmployeeHeader(
              employee: _selectedMonthlyEmployee,
              apiBaseUrl: session.company?.apiBaseUrl,
            ),
            const SizedBox(height: 8),
            if (_canViewTeam)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedEmployeeId.isEmpty ? session.userId : _selectedEmployeeId,
                  isDense: true,
                  decoration: InputDecoration(
                    labelText: 'Employee',
                    labelStyle: const TextStyle(fontSize: 11),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A)),
                  items: _employees
                      .map((e) => DropdownMenuItem(
                            value: '${e['_id']}',
                            child: Text('${e['name']}${e['employeeCode'] != null ? ' · ${e['employeeCode']}' : ''}', style: const TextStyle(fontSize: 11)),
                          ))
                      .toList(),
                  onChanged: (v) async {
                    if (v == null) return;
                    setState(() => _selectedEmployeeId = v);
                    await _loadMonthAttendance();
                  },
                ),
              ),
            _MonthNavigator(
              month: _selectedMonth,
              onChanged: (m) async {
                setState(() => _selectedMonth = m);
                await _loadMonthAttendance();
              },
            ),
            const SizedBox(height: 8),
            if (_monthLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else ...[
              _StatsGrid(
                items: [
                  ('Present', '${_monthStats.present}', const Color(0xFF059669)),
                  ('Late', '${_monthStats.late}', const Color(0xFFD97706)),
                  ('Absent', '${_monthStats.absent}', const Color(0xFFDC2626)),
                  ('On Leave', '${_monthStats.onLeave}', const Color(0xFF7C3AED)),
                  ('Total Hours', _monthStats.totalHours.toStringAsFixed(1), const Color(0xFF2563EB)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Late arrivals counted after ${AttendanceHelpers.lateAfterLabel} · ${_monthRows.where((r) => !r.isFuture).length} working days',
                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      AttendanceHelpers.formatMonthLabel(_selectedMonth),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '${_monthStats.present + _monthStats.late} / ${_monthRows.where((r) => !r.isFuture && r.status != 'On Leave').length} days present',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (_monthRows.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('No records for this month', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
                )
              else
                ..._monthRows.map((row) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _MonthDayCard(
                        row: row,
                        liveClock: _liveClock,
                        onTap: row.isFuture ? null : () => _openMonthDayDetail(row),
                      ),
                    )),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _openMonthDayDetail(({String dateKey, Map<String, dynamic>? att, String status, bool isFuture}) row) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MonthDayDetailSheet(row: row, liveClock: _liveClock),
    );
  }
}

class _CheckInPanel extends StatelessWidget {
  const _CheckInPanel({
    required this.liveClock,
    required this.selectedDate,
    required this.isToday,
    required this.isSessionActive,
    required this.hasCheckedOut,
    required this.canCheckIn,
    required this.canCheckOut,
    required this.isBreakActive,
    required this.isMeetingActive,
    required this.actionLoading,
    required this.netDuration,
    required this.breakDuration,
    required this.meetingDuration,
    required this.workingHours,
    required this.breakHours,
    required this.meetingHours,
    required this.locationLabel,
    required this.refreshingLocation,
    required this.onRefreshLocation,
    required this.onCheckIn,
    required this.onCheckOut,
    required this.onToggleBreak,
    required this.onToggleMeeting,
    required this.myAttendance,
    required this.myStatus,
    required this.userName,
    required this.userEmail,
    this.photoUrl,
  });

  final DateTime liveClock;
  final String selectedDate;
  final bool isToday;
  final bool isSessionActive;
  final bool hasCheckedOut;
  final bool canCheckIn;
  final bool canCheckOut;
  final bool isBreakActive;
  final bool isMeetingActive;
  final bool actionLoading;
  final String netDuration;
  final String breakDuration;
  final String meetingDuration;
  final String workingHours;
  final String breakHours;
  final String meetingHours;
  final String locationLabel;
  final bool refreshingLocation;
  final VoidCallback onRefreshLocation;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;
  final VoidCallback onToggleBreak;
  final VoidCallback onToggleMeeting;
  final Map<String, dynamic>? myAttendance;
  final String myStatus;
  final String userName;
  final String userEmail;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final (statusBg, statusFg) = AttendanceHelpers.statusColors(myStatus);
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
          Row(
            children: [
              _EmployeeAvatar(name: userName, photoUrl: photoUrl, radius: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('My Attendance', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    if (userName.isNotEmpty)
                      Text(userName, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(999)),
                child: Text(myStatus, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: statusFg)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(AttendanceHelpers.formatClock(liveClock), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()])),
          Text(AttendanceHelpers.formatDateLabel(selectedDate), style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
          if (isSessionActive)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Working · $netDuration', style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
            ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(6)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CURRENT LOCATION', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
                      const SizedBox(height: 2),
                      Text(locationLabel, style: const TextStyle(fontSize: 10, color: Color(0xFF334155))),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: refreshingLocation ? null : onRefreshLocation,
                  child: Text(refreshingLocation ? '…' : 'Refresh', style: const TextStyle(fontSize: 10)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: actionLoading || !canCheckIn ? null : onCheckIn,
                  child: const Text('Check In', style: TextStyle(fontSize: 11)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: actionLoading || !canCheckOut ? null : onCheckOut,
                  child: const Text('Check Out', style: TextStyle(fontSize: 11)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: actionLoading || !isSessionActive ? null : onToggleBreak,
                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFB45309)),
                  child: Text(isBreakActive ? 'End Break' : 'Start Break', style: const TextStyle(fontSize: 10)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  onPressed: actionLoading || !isSessionActive ? null : onToggleMeeting,
                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF6D28D9)),
                  child: Text(isMeetingActive ? 'End Meeting' : 'Start Meeting', style: const TextStyle(fontSize: 10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: Text('Break: $breakDuration', style: TextStyle(fontSize: 9, color: isBreakActive ? const Color(0xFFB45309) : const Color(0xFF94A3B8)))),
              Expanded(child: Text('Meeting: $meetingDuration', textAlign: TextAlign.end, style: TextStyle(fontSize: 9, color: isMeetingActive ? const Color(0xFF6D28D9) : const Color(0xFF94A3B8)))),
            ],
          ),
          if (!isToday)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Check-in is only available for today.', style: TextStyle(fontSize: 10, color: Color(0xFFD97706))),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              _MiniStat(label: 'Working', value: '${workingHours}h'),
              _MiniStat(label: 'Break', value: '${breakHours}h'),
              _MiniStat(label: 'Meeting', value: '${meetingHours}h'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(6)),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF64748B))),
            Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _DatePickerRow extends StatelessWidget {
  const _DatePickerRow({required this.date, required this.maxDate, required this.onChanged, required this.onToday});
  final String date;
  final String maxDate;
  final ValueChanged<String> onChanged;
  final VoidCallback onToday;

  Future<void> _pick(BuildContext context) async {
    final initial = DateTime.tryParse('${date}T12:00:00') ?? DateTime.now();
    final max = DateTime.tryParse('${maxDate}T12:00:00') ?? DateTime.now();
    final picked = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2020), lastDate: max);
    if (picked != null) onChanged(AttendanceHelpers.todayKey(picked));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => _pick(context),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(date, style: const TextStyle(fontSize: 11)),
            ),
          ),
        ),
        if (date != maxDate) ...[
          const SizedBox(width: 6),
          TextButton(onPressed: onToday, child: const Text('Today', style: TextStyle(fontSize: 10))),
        ],
      ],
    );
  }
}

class _MonthNavigator extends StatelessWidget {
  const _MonthNavigator({required this.month, required this.onChanged});
  final String month;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final canNext = AttendanceHelpers.canGoToNextMonth(month);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => onChanged(AttendanceHelpers.shiftMonthKey(month, -1)),
            icon: const Icon(Icons.chevron_left, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          Expanded(
            child: Text(
              AttendanceHelpers.formatMonthLabel(month),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            onPressed: canNext ? () => onChanged(AttendanceHelpers.shiftMonthKey(month, 1)) : null,
            icon: Icon(Icons.chevron_right, size: 20, color: canNext ? null : const Color(0xFFCBD5E1)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

class _MonthlyEmployeeHeader extends StatelessWidget {
  const _MonthlyEmployeeHeader({this.employee, this.apiBaseUrl});
  final Map<String, dynamic>? employee;
  final String? apiBaseUrl;

  @override
  Widget build(BuildContext context) {
    if (employee == null) return const SizedBox.shrink();
    final name = AttendanceHelpers.employeeNameFrom(employee);
    final photoUrl = AttendanceHelpers.profilePhotoUrl(employee, apiBaseUrl: apiBaseUrl);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          _EmployeeAvatar(name: name, photoUrl: photoUrl, radius: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                Text(
                  [
                    if (employee!['employeeCode'] != null) '${employee!['employeeCode']}',
                    if (employee!['email'] != null) '${employee!['email']}',
                  ].join(' · '),
                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthDayDetailSheet extends StatelessWidget {
  const _MonthDayDetailSheet({required this.row, required this.liveClock});
  final ({String dateKey, Map<String, dynamic>? att, String status, bool isFuture}) row;
  final DateTime liveClock;

  @override
  Widget build(BuildContext context) {
    final att = row.att;
    final durationHrs = AttendanceHelpers.formatDurationHours(att, liveClock);
    return Container(
      margin: const EdgeInsets.only(top: 48),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        shrinkWrap: true,
        children: [
          Center(
            child: Container(width: 36, height: 4, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 12),
          Text(AttendanceHelpers.formatDateLabel(row.dateKey), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(AttendanceHelpers.formatShortDate(row.dateKey), style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatusBadge(status: row.status),
              if (att?['status'] != null && att!['status'] != row.status) ...[
                const SizedBox(width: 6),
                _StatusBadge(status: att['status']?.toString() ?? ''),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _detailRow('Check In', AttendanceHelpers.formatTimeOnly(att?['checkIn'])),
          _detailRow('Check Out', AttendanceHelpers.formatTimeOnly(att?['checkOut'])),
          _detailRow('Duration', AttendanceHelpers.formatDurationMs(AttendanceHelpers.durationMs(att, liveClock))),
          if (durationHrs.isNotEmpty) _detailRow('Hours', durationHrs),
          _detailRow('Check-in location', '${att?['checkInAddress'] ?? '—'}'),
          _detailRow('Check-out location', '${att?['checkOutAddress'] ?? '—'}'),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Close', style: TextStyle(fontSize: 12))),
        ],
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

class _MonthDayCard extends StatelessWidget {
  const _MonthDayCard({required this.row, required this.liveClock, this.onTap});
  final ({String dateKey, Map<String, dynamic>? att, String status, bool isFuture}) row;
  final DateTime liveClock;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final d = DateTime.tryParse('${row.dateKey}T12:00:00');
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final att = row.att;
    final hours = AttendanceHelpers.formatDurationHours(att, liveClock);
    final isToday = row.dateKey == AttendanceHelpers.todayKey();
    return Opacity(
      opacity: row.isFuture ? 0.45 : 1,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isToday ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 52,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${d?.day ?? ''}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isToday ? const Color(0xFF2563EB) : const Color(0xFF0F172A))),
                          Text(d == null ? '' : weekdays[d.weekday - 1], style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${AttendanceHelpers.formatTimeOnly(att?['checkIn'])} → ${AttendanceHelpers.formatTimeOnly(att?['checkOut'])}',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AttendanceHelpers.formatDurationMs(AttendanceHelpers.durationMs(att, liveClock)),
                            style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                          ),
                          if (att?['checkInAddress'] != null) ...[
                            const SizedBox(height: 4),
                            Text('📍 ${att!['checkInAddress']}', style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (row.isFuture)
                          const Text('—', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)))
                        else
                          _StatusBadge(status: row.status),
                        if (hours.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('${hours}h', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.items});
  final List<(String, String, Color)> items;

  @override
  Widget build(BuildContext context) {
    final w = (MediaQuery.sizeOf(context).width - 26) / 2;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items
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
                      Container(height: 2, color: c.$3),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.$1, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                            Text(c.$2, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = AttendanceHelpers.statusColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(status, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

class _TeamAttendanceCard extends StatelessWidget {
  const _TeamAttendanceCard({required this.row, required this.liveClock, this.apiBaseUrl});
  final ({Map<String, dynamic> emp, Map<String, dynamic>? att, String status}) row;
  final DateTime liveClock;
  final String? apiBaseUrl;

  @override
  Widget build(BuildContext context) {
    final att = row.att;
    final name = AttendanceHelpers.employeeNameFrom(row.emp);
    final photoUrl = AttendanceHelpers.profilePhotoUrl(row.emp, apiBaseUrl: apiBaseUrl);
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
          Row(
            children: [
              _EmployeeAvatar(name: name, photoUrl: photoUrl, radius: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    Text(AttendanceHelpers.designationFrom(row.emp), style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
              _StatusBadge(status: row.status),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _timeBlock('In', AttendanceHelpers.formatTimeOnly(att?['checkIn']))),
              Expanded(child: _timeBlock('Out', AttendanceHelpers.formatTimeOnly(att?['checkOut']))),
              Expanded(child: _timeBlock('Duration', AttendanceHelpers.formatDurationMs(AttendanceHelpers.durationMs(att, liveClock)))),
            ],
          ),
          if (att?['checkInAddress'] != null) ...[
            const SizedBox(height: 6),
            Text('In: ${att!['checkInAddress']}', style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }

  Widget _timeBlock(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
        Text(value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _EmployeeAvatar extends StatefulWidget {
  const _EmployeeAvatar({required this.name, this.photoUrl, this.radius = 16});
  final String name;
  final String? photoUrl;
  final double radius;

  @override
  State<_EmployeeAvatar> createState() => _EmployeeAvatarState();
}

class _EmployeeAvatarState extends State<_EmployeeAvatar> {
  bool _imgError = false;

  @override
  void didUpdateWidget(covariant _EmployeeAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoUrl != widget.photoUrl) _imgError = false;
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.name.isNotEmpty && widget.name != '—' ? widget.name[0].toUpperCase() : '?';
    final photo = widget.photoUrl;
    final showPhoto = photo != null && photo.isNotEmpty && !_imgError;
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: const Color(0xFFDBEAFE),
      backgroundImage: showPhoto ? NetworkImage(photo) : null,
      onBackgroundImageError: (_, __) {
        if (mounted) setState(() => _imgError = true);
      },
      child: showPhoto
          ? null
          : Text(
              initial,
              style: TextStyle(
                fontSize: widget.radius * 0.55,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1D4ED8),
              ),
            ),
    );
  }
}

class _MyDayRecordCard extends StatelessWidget {
  const _MyDayRecordCard({
    required this.attendance,
    required this.status,
    required this.liveClock,
    required this.dateLabel,
  });

  final Map<String, dynamic>? attendance;
  final String status;
  final DateTime liveClock;
  final String dateLabel;

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
          Row(
            children: [
              Expanded(child: Text(dateLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
              _StatusBadge(status: status),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text('In: ${AttendanceHelpers.formatTimeOnly(attendance?['checkIn'])}', style: const TextStyle(fontSize: 10))),
              Expanded(child: Text('Out: ${AttendanceHelpers.formatTimeOnly(attendance?['checkOut'])}', style: const TextStyle(fontSize: 10))),
            ],
          ),
          const SizedBox(height: 4),
          Text('Duration: ${AttendanceHelpers.formatDurationMs(AttendanceHelpers.durationMs(attendance, liveClock))}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
          if (attendance?['checkInAddress'] != null) ...[
            const SizedBox(height: 6),
            Text('Check-in: ${attendance!['checkInAddress']}', style: const TextStyle(fontSize: 9, color: Color(0xFF64748B))),
          ],
          if (attendance?['checkOutAddress'] != null)
            Text('Check-out: ${attendance!['checkOutAddress']}', style: const TextStyle(fontSize: 9, color: Color(0xFF64748B))),
        ],
      ),
    );
  }
}
