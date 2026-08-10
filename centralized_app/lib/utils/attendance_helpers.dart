import 'package:flutter/material.dart';

import 'ist_time.dart';

/// Attendance helpers mirroring web `attendanceLate.js` and `AttendanceView.jsx`.
class AttendanceHelpers {
  AttendanceHelpers._();

  static const officeStartHour = 10;
  static const officeStartMinute = 0;
  static const graceMinutes = 15;

  static String get lateAfterLabel {
    final total = officeStartMinute + graceMinutes;
    final hour = officeStartHour + total ~/ 60;
    final minute = total % 60;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  static bool isLateCheckIn(dynamic checkIn) {
    final d = parseLocalDateTime(checkIn);
    if (d == null) return false;
    final total = officeStartMinute + graceMinutes;
    final lateHour = officeStartHour + total ~/ 60;
    final lateMinute = total % 60;
    final checkMinutes = d.hour * 60 + d.minute;
    final lateAfterMinutes = lateHour * 60 + lateMinute;
    return checkMinutes > lateAfterMinutes;
  }

  static String deriveLiveStatus(Map<String, dynamic>? attendance, bool onLeave) {
    if (onLeave) return 'On Leave';
    if (attendance?['checkIn'] == null) return 'Absent';
    if (isLateCheckIn(attendance!['checkIn'])) return 'Late';
    final status = attendance['status']?.toString();
    if (status == 'In Progress') return 'Present';
    if (status == 'Full Day' || status == 'Half Day') return 'Present';
    return status ?? 'Present';
  }

  static DateTime? parseDateTime(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  /// Parse as IST wall-clock (UTC+05:30) — CRM times are India-based.
  static DateTime? parseLocalDateTime(dynamic v) => IstTime.parse(v);

  static String formatTimeOfDay(DateTime d) => IstTime.formatTimeOfDay(d);

  static String todayKey([DateTime? ref]) => IstTime.dateKey(ref);

  static String monthKey([DateTime? ref]) {
    final d = ref != null ? IstTime.toIst(ref.toUtc()) : IstTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}';
  }

  static String dateKeyFrom(dynamic value) {
    if (value == null) return '';
    final raw = value.toString();
    if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(raw)) return raw.substring(0, 10);
    final d = parseLocalDateTime(value);
    if (d == null) return '';
    return todayKey(d);
  }

  /// Date key for an attendance row (mirrors web `toDateKey(a.date)`).
  static String attendanceDateKey(Map<String, dynamic> record) {
    if (record['date'] != null) return dateKeyFrom(record['date']);
    return '';
  }

  static Map<String, Map<String, dynamic>> indexByDate(List<Map<String, dynamic>> records) {
    final map = <String, Map<String, dynamic>>{};
    for (final record in records) {
      final key = attendanceDateKey(record);
      if (key.isNotEmpty) map[key] = record;
    }
    return map;
  }

  static String shiftMonthKey(String currentMonth, int delta) {
    final parts = currentMonth.split('-');
    if (parts.length != 2) return currentMonth;
    final y = int.tryParse(parts[0]) ?? DateTime.now().year;
    final m = int.tryParse(parts[1]) ?? DateTime.now().month;
    final d = DateTime(y, m + delta);
    return AttendanceHelpers.monthKey(d);
  }

  static bool canGoToNextMonth(String currentMonth) => currentMonth.compareTo(monthKey()) < 0;

  static String formatShortDate(String dateKey) {
    final d = DateTime.tryParse('${dateKey}T12:00:00');
    if (d == null) return dateKey;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  static String formatDurationHours(Map<String, dynamic>? row, [DateTime? now]) {
    final stored = num.tryParse('${row?['durationHours']}');
    if (stored != null && row?['checkOut'] != null) return stored.toStringAsFixed(2);
    final ms = durationMs(row, now);
    if (ms == null) return '';
    return (ms / 3600000).toStringAsFixed(2);
  }

  static List<String> daysInMonth(String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length != 2) return [];
    final y = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    if (y == 0 || m == 0) return [];
    final count = DateTime(y, m + 1, 0).day;
    return List.generate(count, (i) {
      final day = i + 1;
      return '$y-${m.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    });
  }

  static String formatClock(DateTime d) {
    final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    final m = d.minute.toString().padLeft(2, '0');
    final s = d.second.toString().padLeft(2, '0');
    return '$h:$m:$s $ampm';
  }

  static String formatTimeOnly(dynamic value) => IstTime.formatTimeOfDay(value);

  static String formatDateLabel(String dateKey) {
    final d = DateTime.tryParse('${dateKey}T12:00:00');
    if (d == null) return dateKey;
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${weekdays[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  static String formatMonthLabel(String monthKey) {
    final d = DateTime.tryParse('${monthKey}-01T12:00:00');
    if (d == null) return monthKey;
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${months[d.month - 1]} ${d.year}';
  }

  static String formatCoords(double lat, double lon) =>
      '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}';

  static double trackedMinutes(Map<String, dynamic>? row, String startedAtKey, String totalMinutesKey, [DateTime? now]) {
    final saved = num.tryParse('${row?[totalMinutesKey]}')?.toDouble() ?? 0;
    final started = parseDateTime(row?[startedAtKey]);
    if (started == null) return saved;
    final ref = now ?? DateTime.now();
    final live = (ref.difference(started).inMilliseconds / 60000).clamp(0, double.infinity);
    return saved + live;
  }

  static int? durationMs(Map<String, dynamic>? row, [DateTime? now]) {
    if (row?['checkIn'] == null) return null;
    final start = parseDateTime(row!['checkIn']);
    if (start == null) return null;
    final ref = now ?? DateTime.now();
    final end = row['checkOut'] != null ? parseDateTime(row['checkOut']) : ref;
    if (end == null) return null;
    final breakMinutes = trackedMinutes(row, 'breakStartedAt', 'breakDurationMinutes', ref);
    final ms = end.difference(start).inMilliseconds - (breakMinutes * 60000).round();
    return ms < 0 ? 0 : ms;
  }

  static String formatDurationMs(int? ms) {
    if (ms == null) return '—';
    final totalSeconds = ms ~/ 1000;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  static double hoursFromRow(Map<String, dynamic>? row, [DateTime? now]) {
    final ms = durationMs(row, now);
    return ms == null ? 0 : ms / 3600000;
  }

  static String employeeIdFrom(dynamic employee) {
    if (employee is Map) return '${employee['_id'] ?? ''}';
    return employee?.toString() ?? '';
  }

  static String employeeNameFrom(dynamic employee) {
    if (employee is Map) return (employee['name'] ?? '—').toString();
    return '—';
  }

  static String designationFrom(dynamic employee) {
    if (employee is! Map) return '—';
    final d = employee['designation'];
    if (d is Map) return (d['title'] ?? d['name'] ?? '—').toString();
    if (d is String && d.trim().isNotEmpty) return d.trim();
    return (employee['department'] ?? '—').toString();
  }

  static String? profilePhotoUrl(Map<String, dynamic>? employee, {String? apiBaseUrl}) {
    if (employee == null) return null;
    final raw = employee['profilePhoto']?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (apiBaseUrl != null && raw.startsWith('/')) {
      final base = apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
      return '$base$raw';
    }
    return raw;
  }

  static bool isOnLeave(List<Map<String, dynamic>> leaves, String employeeId, String dateKey) {
    final day = DateTime.tryParse('${dateKey}T12:00:00');
    if (day == null) return false;
    for (final l in leaves) {
      if (l['status'] != 'Approved') continue;
      if (employeeIdFrom(l['employee']) != employeeId) continue;
      final start = parseLocalDateTime(l['startDate']);
      final end = parseLocalDateTime(l['endDate']);
      if (start == null || end == null) continue;
      final s = DateTime(start.year, start.month, start.day);
      final e = DateTime(end.year, end.month, end.day, 23, 59, 59);
      if (!day.isBefore(s) && !day.isAfter(e)) return true;
    }
    return false;
  }

  static (Color bg, Color fg) statusColors(String? status) {
    switch (status) {
      case 'Present':
      case 'Full Day':
        return (const Color(0xFFECFDF5), const Color(0xFF047857));
      case 'Late':
      case 'Half Day':
        return (const Color(0xFFFFFBEB), const Color(0xFFB45309));
      case 'Absent':
        return (const Color(0xFFFEF2F2), const Color(0xFFB91C1C));
      case 'On Leave':
        return (const Color(0xFFF5F3FF), const Color(0xFF6D28D9));
      case 'In Progress':
        return (const Color(0xFFEFF6FF), const Color(0xFF1D4ED8));
      default:
        return (const Color(0xFFF8FAFC), const Color(0xFF475569));
    }
  }
}
