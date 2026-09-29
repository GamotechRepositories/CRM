import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_cache.dart';
import '../api/company_api.dart';
import '../auth/auth_session.dart';
import '../utils/attendance_helpers.dart';
import '../utils/ist_time.dart';
import 'chat_realtime_service.dart';
import 'notification_service.dart';

/// Employee-facing reminders: new task assignments, shift check-in / check-out
/// times (from the company profile `workingHours`), and break start / ending.
class WorkReminderService {
  WorkReminderService._();
  static final WorkReminderService instance = WorkReminderService._();

  static const _checkInBaseId = 20000;
  static const _checkOutBaseId = 21000;
  static const _breakStartedId = 30001;
  static const _breakEndingId = 30002;
  static const _breakOverId = 30003;
  static const _tasksSummaryId = 40000;
  static const _taskBaseId = 1000000;

  static const _scheduleDays = 7;
  static const _breakWarningMinutes = 5;
  static const _maxKnownTasks = 500;

  StreamSubscription<Map<String, dynamic>>? _taskSub;
  String? _sessionKey;
  DateTime? _lastRefresh;

  int _breakAllowanceMinutes = 45;
  ({int hour, int minute})? _shiftStart;
  ({int hour, int minute})? _shiftEnd;

  /// Call once the user is logged in. Reuses cached / in-flight responses so it
  /// never duplicates the dashboard's own requests.
  Future<void> start(AuthSession session) async {
    final api = session.api;
    final userId = session.userId;
    if (api == null || userId.isEmpty) return;

    final key = '${api.company.key}:$userId';
    if (_sessionKey == key) return;
    _sessionKey = key;
    _lastRefresh = null;
    _listenForTasks(api, userId);
    await refresh(session);
    await NotificationService.instance.requestPermissions();
  }

  /// Re-syncs scheduled reminders and catches up on tasks assigned while the
  /// app was closed. Throttled so rapid resumes don't spam the API.
  /// [fresh] bypasses the API cache (used on app resume).
  Future<void> refresh(AuthSession session, {bool fresh = false}) async {
    final api = session.api;
    final userId = session.userId;
    if (api == null || userId.isEmpty || _sessionKey == null) return;
    final now = DateTime.now();
    if (_lastRefresh != null && now.difference(_lastRefresh!) < const Duration(minutes: 1)) {
      return;
    }
    _lastRefresh = now;
    Future<void> run() => Future.wait([
          _catchUpOnTasks(api, userId),
          _syncAttendanceReminders(api, userId, session.user),
        ]);
    await (fresh ? ApiCache.fresh(run) : run());
  }

  Future<void> stop() async {
    await _taskSub?.cancel();
    _taskSub = null;
    _sessionKey = null;
    _lastRefresh = null;
    ChatRealtimeService.instance.disconnect();
    await NotificationService.instance.cancelAll();
  }

  // ---------------------------------------------------------------------------
  // Tasks
  // ---------------------------------------------------------------------------

  void _listenForTasks(CompanyApi api, String userId) {
    ChatRealtimeService.instance.connect(
      socketOrigin: Uri.parse(api.company.apiBaseUrl).origin,
      userId: userId,
      tenantId: api.company.key,
    );
    _taskSub?.cancel();
    _taskSub = ChatRealtimeService.instance.taskChanges.listen((event) async {
      ApiCache.clear();
      if (event['reason'] != 'assigned') return;
      final taskId = (event['taskId'] ?? '').toString();
      if (taskId.isNotEmpty) {
        final known = await _loadKnownTasks(api, userId);
        if (known != null && known.contains(taskId)) return;
        await _saveKnownTasks(api, userId, {...?known, taskId});
      }
      await _notifyTask(taskId, (event['title'] ?? '').toString());
    });
  }

  Future<void> _catchUpOnTasks(CompanyApi api, String userId) async {
    try {
      final tasks = await api.fetchTasks(query: {'employeeId': userId});
      final mine = tasks.where((t) => _refId(t['assignedTo']) == userId).toList();
      final ids = mine.map((t) => '${t['_id'] ?? ''}').where((id) => id.isNotEmpty).toSet();

      final known = await _loadKnownTasks(api, userId);
      await _saveKnownTasks(api, userId, {...?known, ...ids});
      // First run on this device: remember existing tasks without alerting.
      if (known == null) return;

      final fresh = mine
          .where((t) => !known.contains('${t['_id']}'))
          .where((t) => '${t['status'] ?? ''}' != 'Completed')
          .toList();
      if (fresh.isEmpty) return;
      if (fresh.length == 1) {
        await _notifyTask('${fresh.first['_id']}', '${fresh.first['title'] ?? ''}');
      } else {
        await NotificationService.instance.show(
          id: _tasksSummaryId,
          title: '${fresh.length} new tasks assigned',
          body: fresh.map((t) => '${t['title'] ?? 'Task'}').take(4).join(', '),
          channel: NotificationChannel.tasks,
        );
      }
    } catch (e) {
      debugPrint('Task catch-up failed: $e');
    }
  }

  Future<void> _notifyTask(String taskId, String title) {
    final id = taskId.isEmpty
        ? _taskBaseId + DateTime.now().millisecondsSinceEpoch % 1000000
        : _taskBaseId + (taskId.hashCode & 0x7fffffff) % 1000000;
    return NotificationService.instance.show(
      id: id,
      title: 'New task assigned',
      body: title.trim().isEmpty ? 'You have a new task. Open the app to view it.' : title.trim(),
      channel: NotificationChannel.tasks,
    );
  }

  String _knownTasksKey(CompanyApi api, String userId) => 'crm_known_tasks_${api.company.key}_$userId';

  Future<Set<String>?> _loadKnownTasks(CompanyApi api, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_knownTasksKey(api, userId))?.toSet();
  }

  Future<void> _saveKnownTasks(CompanyApi api, String userId, Set<String> ids) async {
    final list = ids.toList();
    final trimmed = list.length > _maxKnownTasks ? list.sublist(list.length - _maxKnownTasks) : list;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_knownTasksKey(api, userId), trimmed);
  }

  // ---------------------------------------------------------------------------
  // Shift check-in / check-out
  // ---------------------------------------------------------------------------

  Future<void> _syncAttendanceReminders(
    CompanyApi api,
    String userId,
    Map<String, dynamic>? user,
  ) async {
    try {
      final results = await Future.wait([
        api.fetchCompanyProfile(),
        api.fetchAttendanceToday(employeeId: userId),
      ]);
      final profile = results[0] as Map<String, dynamic>;
      final todayRows = results[1] as List<Map<String, dynamic>>;

      _breakAllowanceMinutes = int.tryParse('${profile['breakTimeMinutes'] ?? ''}') ?? 45;
      final hours = parseWorkingHours('${profile['workingHours'] ?? ''}') ??
          parseWorkingHours('${user?['workingHours'] ?? ''}') ??
          parseWorkingHours('9 AM - 6 PM');
      _shiftStart = hours?.start;
      _shiftEnd = hours?.end;

      Map<String, dynamic>? today;
      for (final row in todayRows) {
        if (AttendanceHelpers.employeeIdFrom(row['employee']) == userId) today = row;
      }

      await _scheduleShiftReminders(
        checkedInToday: today?['checkIn'] != null,
        checkedOutToday: today?['checkOut'] != null,
      );

      if (today != null && today['breakStartedAt'] != null && today['checkOut'] == null) {
        await _scheduleBreakEnding(today);
      } else {
        await _cancelBreakReminders();
      }
    } catch (e) {
      debugPrint('Attendance reminder sync failed: $e');
    }
  }

  Future<void> _scheduleShiftReminders({
    required bool checkedInToday,
    required bool checkedOutToday,
  }) async {
    final start = _shiftStart;
    final end = _shiftEnd;
    final istToday = IstTime.now();

    for (var i = -1; i <= _scheduleDays; i++) {
      final day = DateTime.utc(istToday.year, istToday.month, istToday.day + i);
      await NotificationService.instance.cancel(_checkInBaseId + _dayId(day));
      await NotificationService.instance.cancel(_checkOutBaseId + _dayId(day));
      if (i < 0 || day.weekday == DateTime.sunday) continue;

      final isToday = i == 0;
      if (start != null && !(isToday && checkedInToday)) {
        await NotificationService.instance.scheduleAt(
          id: _checkInBaseId + _dayId(day),
          when: _istInstant(day, start),
          title: 'Time to check in',
          body: "It's ${_formatHm(start)} — don't forget to mark your attendance.",
        );
      }
      if (end != null && !(isToday && checkedOutToday)) {
        await NotificationService.instance.scheduleAt(
          id: _checkOutBaseId + _dayId(day),
          when: _istInstant(day, end),
          title: 'Time to check out',
          body: "It's ${_formatHm(end)} — your shift is over. Remember to check out.",
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Hooks called after attendance actions succeed
  // ---------------------------------------------------------------------------

  Future<void> onCheckedIn() async {
    await NotificationService.instance.cancel(_checkInBaseId + _dayId(_istTodayDate()));
  }

  Future<void> onCheckedOut() async {
    await NotificationService.instance.cancel(_checkOutBaseId + _dayId(_istTodayDate()));
    await _cancelBreakReminders();
  }

  Future<void> onBreakStarted(Map<String, dynamic>? attendance) async {
    final remaining = _remainingBreakMinutes(attendance);
    await NotificationService.instance.show(
      id: _breakStartedId,
      title: 'Break started',
      body: _breakAllowanceMinutes <= 0
          ? 'Enjoy your break.'
          : remaining <= 0
              ? 'You have used your full $_breakAllowanceMinutes min break allowance for today.'
              : 'You have $remaining min of break time left today.',
    );
    if (attendance != null) await _scheduleBreakEnding(attendance);
  }

  Future<void> onBreakEnded() async {
    await _cancelBreakReminders();
    await NotificationService.instance.cancel(_breakStartedId);
  }

  // ---------------------------------------------------------------------------
  // Break helpers
  // ---------------------------------------------------------------------------

  /// Minutes of daily break allowance left before the current break started.
  int _remainingBreakMinutes(Map<String, dynamic>? attendance) {
    final used = num.tryParse('${attendance?['breakDurationMinutes'] ?? 0}')?.toInt() ?? 0;
    return _breakAllowanceMinutes - used;
  }

  Future<void> _scheduleBreakEnding(Map<String, dynamic> attendance) async {
    await _cancelBreakReminders();
    if (_breakAllowanceMinutes <= 0) return;
    final startedAt = AttendanceHelpers.parseDateTime(attendance['breakStartedAt']);
    if (startedAt == null) return;
    final remaining = _remainingBreakMinutes(attendance);
    if (remaining <= 0) return;

    final endsAt = startedAt.add(Duration(minutes: remaining));
    final warnLead = remaining > _breakWarningMinutes ? _breakWarningMinutes : 1;
    if (remaining > 1) {
      await NotificationService.instance.scheduleAt(
        id: _breakEndingId,
        when: endsAt.subtract(Duration(minutes: warnLead)),
        title: 'Break ending soon',
        body: 'Your break ends in $warnLead min. Please get ready to resume work.',
      );
    }
    await NotificationService.instance.scheduleAt(
      id: _breakOverId,
      when: endsAt,
      title: 'Break time over',
      body: 'Your break allowance is used up. Please end your break and resume work.',
    );
  }

  Future<void> _cancelBreakReminders() async {
    await NotificationService.instance.cancel(_breakEndingId);
    await NotificationService.instance.cancel(_breakOverId);
  }

  // ---------------------------------------------------------------------------
  // Time helpers
  // ---------------------------------------------------------------------------

  /// Parses strings like `9 AM - 6 PM`, `9:30am to 6:30pm`, `09:00-18:00`.
  @visibleForTesting
  static ({({int hour, int minute}) start, ({int hour, int minute}) end})? parseWorkingHours(String raw) {
    final matches = RegExp(r'(\d{1,2})(?:[:.](\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)?', caseSensitive: false)
        .allMatches(raw)
        .toList();
    if (matches.length < 2) return null;

    ({int hour, int minute})? toTime(RegExpMatch m) {
      var h = int.parse(m.group(1)!);
      final min = int.tryParse(m.group(2) ?? '0') ?? 0;
      final suffix = (m.group(3) ?? '').toLowerCase().replaceAll('.', '');
      if (h > 23 || min > 59) return null;
      if (suffix == 'pm' && h < 12) h += 12;
      if (suffix == 'am' && h == 12) h = 0;
      return (hour: h, minute: min);
    }

    final start = toTime(matches[0]);
    var end = toTime(matches[1]);
    if (start == null || end == null) return null;
    final endHasSuffix = (matches[1].group(3) ?? '').isNotEmpty;
    if (!endHasSuffix && end.hour * 60 + end.minute <= start.hour * 60 + start.minute && end.hour < 12) {
      end = (hour: end.hour + 12, minute: end.minute);
    }
    return (start: start, end: end);
  }

  static DateTime _istTodayDate() {
    final now = IstTime.now();
    return DateTime.utc(now.year, now.month, now.day);
  }

  static DateTime _istInstant(DateTime istDay, ({int hour, int minute}) t) =>
      DateTime.utc(istDay.year, istDay.month, istDay.day, t.hour, t.minute).subtract(IstTime.offset);

  static int _dayId(DateTime istDay) => (istDay.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay) % 100;

  static String _formatHm(({int hour, int minute}) t) {
    final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final ampm = t.hour >= 12 ? 'PM' : 'AM';
    return '$h12:${t.minute.toString().padLeft(2, '0')} $ampm';
  }

  static String _refId(dynamic value) {
    if (value is Map) return '${value['_id'] ?? ''}';
    return value?.toString() ?? '';
  }
}
