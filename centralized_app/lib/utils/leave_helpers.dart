import 'package:flutter/material.dart';

/// Leave module constants and formatting (mirrors web `LeaveView.jsx`).
class LeaveHelpers {
  LeaveHelpers._();

  static const leaveTypes = ['Sick', 'Casual', 'Annual', 'Unpaid', 'Other'];

  static const leaveTypeLabels = {
    'Sick': 'Sick Leave',
    'Casual': 'Casual Leave',
    'Annual': 'Earned Leave',
    'Unpaid': 'Unpaid Leave',
    'Other': 'Other',
  };

  static const stageLabels = {
    'team_leader': 'Team Leader / Reporting Manager',
    'hr': 'HR Manager',
    'admin': 'Admin',
    'central_admin': 'Centralized Admin',
    'completed': 'Completed',
  };

  static String leaveTypeLabel(String? type) =>
      leaveTypeLabels[type] ?? type ?? '—';

  static String stageLabel(String? stage, {required String status}) {
    if (status != 'Pending') return stageLabels['completed']!;
    return stageLabels[stage ?? 'team_leader'] ?? stage ?? '—';
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
    if (d is String && d.trim().isNotEmpty && !RegExp(r'^[a-f\d]{24}$', caseSensitive: false).hasMatch(d.trim())) {
      return d.trim();
    }
    return (employee['department'] ?? '—').toString();
  }

  static DateTime? parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  static DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool leaveInDateRange(Map<String, dynamic> leave, DateTime? from, DateTime? to) {
    if (from == null && to == null) return true;
    final leaveStart = parseDate(leave['startDate']);
    final leaveEnd = parseDate(leave['endDate']);
    if (leaveStart == null || leaveEnd == null) return false;
    final s = startOfDay(leaveStart);
    final e = startOfDay(leaveEnd);
    final rangeStart = from != null ? startOfDay(from) : DateTime.fromMillisecondsSinceEpoch(0);
    final rangeEnd = to != null ? startOfDay(to) : DateTime(2100);
    return !e.isBefore(rangeStart) && !s.isAfter(rangeEnd);
  }

  static bool isOnCalendarDay(Map<String, dynamic> leave, int year, int month, int day) {
    final key = DateTime(year, month, day);
    final ts = startOfDay(key);
    final s = parseDate(leave['startDate']);
    final e = parseDate(leave['endDate']);
    if (s == null || e == null) return false;
    return !ts.isBefore(startOfDay(s)) && !ts.isAfter(startOfDay(e));
  }

  static String formatLeaveDate(dynamic value) {
    final d = parseDate(value);
    if (d == null) return '—';
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}, ${weekdays[d.weekday - 1]}';
  }

  static String formatAppliedOn(dynamic value) {
    final d = parseDate(value);
    if (d == null) return '—';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}, $h:$m $ampm';
  }

  static String ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime monthStart(DateTime ref) => DateTime(ref.year, ref.month, 1);

  static DateTime monthEnd(DateTime ref) => DateTime(ref.year, ref.month + 1, 0);

  static (Color bg, Color fg) leaveTypeColors(String? type) {
    switch (type) {
      case 'Casual':
        return (const Color(0xFFEFF6FF), const Color(0xFF1D4ED8));
      case 'Sick':
        return (const Color(0xFFECFDF5), const Color(0xFF047857));
      case 'Annual':
        return (const Color(0xFFF5F3FF), const Color(0xFF6D28D9));
      case 'Unpaid':
        return (const Color(0xFFF8FAFC), const Color(0xFF475569));
      default:
        return (const Color(0xFFF9FAFB), const Color(0xFF374151));
    }
  }

  static (Color bg, Color fg) statusColors(String? status) {
    switch (status) {
      case 'Approved':
        return (const Color(0xFFECFDF5), const Color(0xFF047857));
      case 'Pending':
        return (const Color(0xFFFFFBEB), const Color(0xFFB45309));
      case 'Rejected':
        return (const Color(0xFFFEF2F2), const Color(0xFFB91C1C));
      default:
        return (const Color(0xFFF8FAFC), const Color(0xFF475569));
    }
  }
}
