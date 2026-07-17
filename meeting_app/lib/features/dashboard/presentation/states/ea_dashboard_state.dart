import 'package:equatable/equatable.dart';

import '../../../meetings/domain/entities/meeting.dart';
import '../../domain/entities/meeting_invitation.dart';
import '../../domain/entities/meeting_request.dart';

enum EaDashboardStatus { initial, loading, ready, error }

class ActivityItem extends Equatable {
  const ActivityItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.at,
    required this.icon,
  });

  final String id;
  final String title;
  final String subtitle;
  final DateTime at;
  final String icon;

  @override
  List<Object?> get props => [id, title, subtitle, at, icon];
}

class EaDashboardState extends Equatable {
  const EaDashboardState({
    this.status = EaDashboardStatus.initial,
    this.meetings = const [],
    this.invitations = const [],
    this.requests = const [],
    this.activity = const [],
    this.selectedDay,
    this.errorMessage,
  });

  final EaDashboardStatus status;
  final List<Meeting> meetings;
  final List<MeetingInvitation> invitations;
  final List<MeetingRequest> requests;
  final List<ActivityItem> activity;
  final DateTime? selectedDay;
  final String? errorMessage;

  bool get isLoading => status == EaDashboardStatus.loading;

  DateTime get focusDay => selectedDay ?? DateTime.now();

  List<Meeting> get todaysMeetings {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return meetings
        .where(
          (m) => !m.scheduledAt.isBefore(start) && m.scheduledAt.isBefore(end),
        )
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  List<Meeting> get upcomingMeetings {
    final now = DateTime.now();
    return meetings.where((m) => m.scheduledAt.isAfter(now)).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  List<Meeting> meetingsOn(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return meetings
        .where(
          (m) => !m.scheduledAt.isBefore(start) && m.scheduledAt.isBefore(end),
        )
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  List<MeetingInvitation> get pendingInvitations =>
      invitations.where((i) => i.isPending).toList();

  List<MeetingRequest> get pendingRequests =>
      requests.where((r) => r.isPending).toList();

  Set<DateTime> get meetingDays {
    return {
      for (final m in meetings)
        DateTime(m.scheduledAt.year, m.scheduledAt.month, m.scheduledAt.day),
    };
  }

  EaDashboardState copyWith({
    EaDashboardStatus? status,
    List<Meeting>? meetings,
    List<MeetingInvitation>? invitations,
    List<MeetingRequest>? requests,
    List<ActivityItem>? activity,
    DateTime? selectedDay,
    bool clearSelectedDay = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return EaDashboardState(
      status: status ?? this.status,
      meetings: meetings ?? this.meetings,
      invitations: invitations ?? this.invitations,
      requests: requests ?? this.requests,
      activity: activity ?? this.activity,
      selectedDay: clearSelectedDay ? null : (selectedDay ?? this.selectedDay),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    status,
    meetings,
    invitations,
    requests,
    activity,
    selectedDay,
    errorMessage,
  ];
}
