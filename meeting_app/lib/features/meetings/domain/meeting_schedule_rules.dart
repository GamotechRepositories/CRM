import 'entities/meeting.dart';

/// Shared schedule rules for employee meeting create/edit.
abstract final class MeetingScheduleRules {
  /// True when [start] is before "now" (1 minute grace for clock skew).
  static bool isInThePast(DateTime start, {DateTime? now}) {
    final reference = (now ?? DateTime.now()).subtract(const Duration(minutes: 1));
    return start.isBefore(reference);
  }

  /// True when [start]..[end] overlaps another active meeting.
  static bool overlaps({
    required DateTime start,
    required DateTime end,
    required List<Meeting> existing,
    String? excludeMeetingId,
  }) {
    if (!end.isAfter(start)) return false;

    for (final meeting in existing) {
      if (excludeMeetingId != null && meeting.id == excludeMeetingId) {
        continue;
      }
      if (!_countsForConflict(meeting)) continue;

      final otherStart = meeting.startAt;
      final otherEnd = meeting.endAt;
      // Overlap: start < otherEnd && otherStart < end
      if (start.isBefore(otherEnd) && otherStart.isBefore(end)) {
        return true;
      }
    }
    return false;
  }

  static Meeting? firstConflict({
    required DateTime start,
    required DateTime end,
    required List<Meeting> existing,
    String? excludeMeetingId,
  }) {
    if (!end.isAfter(start)) return null;

    for (final meeting in existing) {
      if (excludeMeetingId != null && meeting.id == excludeMeetingId) {
        continue;
      }
      if (!_countsForConflict(meeting)) continue;
      if (start.isBefore(meeting.endAt) && meeting.startAt.isBefore(end)) {
        return meeting;
      }
    }
    return null;
  }

  static bool _countsForConflict(Meeting meeting) {
    return switch (meeting.status) {
      MeetingStatus.cancelled || MeetingStatus.missed => false,
      _ => true,
    };
  }

  /// Returns an error message, or null when the slot is valid.
  static String? validateSlot({
    required DateTime start,
    required DateTime end,
    required List<Meeting> existing,
    String? excludeMeetingId,
    DateTime? now,
  }) {
    if (!end.isAfter(start)) {
      return 'End time must be after start time';
    }
    if (isInThePast(start, now: now)) {
      return 'Cannot schedule a meeting in the past. Pick a future time.';
    }
    final conflict = firstConflict(
      start: start,
      end: end,
      existing: existing,
      excludeMeetingId: excludeMeetingId,
    );
    if (conflict != null) {
      return 'Time slot conflicts with “${conflict.title}”. '
          'Choose a different time.';
    }
    return null;
  }
}
