import 'package:flutter/material.dart' show Color;

/// Task status helpers mirroring web `taskStatus.js`.
class TaskStatus {
  TaskStatus._();

  static const statuses = ['Pending', 'In Progress', 'Paused', 'Completed', 'Cancelled'];

  static String normalize(dynamic status) {
    if (status == null || status.toString().trim().isEmpty) return 'Pending';
    final value = status.toString().trim();
    if (value == 'InProgress' || value.toLowerCase() == 'in progress') return 'In Progress';
    if (value.toLowerCase() == 'paused' || value.toLowerCase() == 'on hold') return 'Paused';
    return value;
  }

  static bool isDelayed(Map<String, dynamic> task) {
    final due = task['dueDate'];
    if (due == null) return false;
    final status = normalize(task['status']);
    if (status == 'Completed' || status == 'Cancelled') return false;
    final d = DateTime.tryParse(due.toString());
    if (d == null) return false;
    return d.isBefore(DateTime.now());
  }

  static List<String> editableOptions(Map<String, dynamic> task) {
    final current = normalize(task['status']);
    if (current == 'Paused') {
      return ['Paused', 'In Progress', 'Completed', 'Cancelled'];
    }
    if (current == 'Completed' || current == 'Cancelled') {
      return [current];
    }
    return ['Pending', 'In Progress', 'Paused', 'Completed', 'Cancelled'];
  }

  static (Color bg, Color fg) colors(String status) {
    switch (normalize(status)) {
      case 'Completed':
        return (const Color(0xFFECFDF5), const Color(0xFF047857));
      case 'In Progress':
        return (const Color(0xFFEFF6FF), const Color(0xFF2563EB));
      case 'Paused':
        return (const Color(0xFFF5F3FF), const Color(0xFF7C3AED));
      case 'Pending':
        return (const Color(0xFFFFFBEB), const Color(0xFFB45309));
      case 'Cancelled':
        return (const Color(0xFFF1F5F9), const Color(0xFF64748B));
      default:
        return (const Color(0xFFF1F5F9), const Color(0xFF475569));
    }
  }

  static (Color bg, Color fg) priorityColors(String? priority) {
    switch (priority) {
      case 'Urgent':
        return (const Color(0xFFFEE2E2), const Color(0xFFB91C1C));
      case 'High':
        return (const Color(0xFFFFEDD5), const Color(0xFFC2410C));
      case 'Medium':
        return (const Color(0xFFFEF9C3), const Color(0xFFA16207));
      default:
        return (const Color(0xFFECFDF5), const Color(0xFF047857));
    }
  }
}
