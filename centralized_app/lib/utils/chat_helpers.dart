import 'package:flutter/material.dart';

import 'ist_time.dart';

class ChatHelpers {
  ChatHelpers._();

  static String conversationTitle(Map<String, dynamic> conversation) {
    final type = conversation['type']?.toString();
    if (type == 'team') return conversation['title']?.toString() ?? 'Team Chat';
    final peer = conversation['peer'];
    if (peer is Map) return (peer['name'] ?? conversation['title'] ?? 'Direct Chat').toString();
    return conversation['title']?.toString() ?? 'Chat';
  }

  static String conversationSubtitle(Map<String, dynamic> conversation) {
    final type = conversation['type']?.toString();
    if (type == 'team') return 'Team channel';
    final peer = conversation['peer'];
    if (peer is Map) {
      final dept = peer['department']?.toString();
      if (dept != null && dept.isNotEmpty) return dept;
    }
    return 'Direct message';
  }

  static String senderName(Map<String, dynamic> message) {
    final sender = message['sender'];
    if (sender is Map) return (sender['name'] ?? 'Member').toString();
    return 'Member';
  }

  static String senderId(Map<String, dynamic> message) {
    final sender = message['sender'];
    if (sender is Map) return '${sender['_id'] ?? ''}';
    if (sender != null) return sender.toString();
    return '';
  }

  static String formatTime(dynamic value) {
    final date = IstTime.parse(value);
    if (date == null) return '';
    final now = IstTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    if (isToday) return IstTime.formatHm(date);
    return IstTime.formatHm(date);
  }

  static String formatListTime(dynamic value) {
    final date = IstTime.parse(value);
    if (date == null) return '';
    final now = IstTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return IstTime.formatHm(date);
    }
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]}';
  }

  static String formatDayLabel(dynamic value) {
    final date = IstTime.parse(value);
    if (date == null) return '';
    final now = IstTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(date.year, date.month, date.day);
    if (msgDay == today) return 'Today';
    if (msgDay == today.subtract(const Duration(days: 1))) return 'Yesterday';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (date.year == now.year) {
      return '${date.day} ${months[date.month - 1]}';
    }
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  static String toDateKey([DateTime? value]) => IstTime.dateKey(value);

  static String previousDayKey(String dayKey) {
    final d = DateTime.tryParse('${dayKey}T12:00:00') ?? DateTime.now();
    return toDateKey(d.subtract(const Duration(days: 1)));
  }

  static List<({String type, String id, dynamic data})> buildChatItems(List<Map<String, dynamic>> messages) {
    final items = <({String type, String id, dynamic data})>[];
    int? lastDay;
    for (final msg in messages) {
      final created = DateTime.tryParse('${msg['createdAt']}');
      if (created != null) {
        final dayKey = DateTime(created.year, created.month, created.day).millisecondsSinceEpoch;
        if (dayKey != lastDay) {
          items.add((type: 'date', id: 'date-$dayKey', data: formatDayLabel(created)));
          lastDay = dayKey;
        }
      }
      items.add((type: 'message', id: '${msg['_id']}', data: msg));
    }
    return items;
  }

  static List<Map<String, dynamic>> mergeMessages(
    List<Map<String, dynamic>> older,
    List<Map<String, dynamic>> current,
  ) {
    final ids = current.map((m) => '${m['_id']}').toSet();
    final uniqueOlder = older.where((m) => !ids.contains('${m['_id']}')).toList();
    return [...uniqueOlder, ...current];
  }

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  static Color avatarColor(String seed) {
    const colors = [
      Color(0xFF2563EB),
      Color(0xFF059669),
      Color(0xFFEA580C),
      Color(0xFF7C3AED),
      Color(0xFFDB2777),
    ];
    var hash = 0;
    for (final c in seed.codeUnits) {
      hash = (hash + c) % colors.length;
    }
    return colors[hash];
  }
}
