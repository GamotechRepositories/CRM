import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../../meetings/domain/entities/meeting.dart';

enum BossQuickFilter { all, today, upcoming, highPriority, team }

/// Meeting enriched with company display metadata for the portfolio dashboard.
class PortfolioMeeting extends Equatable {
  const PortfolioMeeting({
    required this.meeting,
    required this.companyName,
    required this.chipLabel,
    required this.companyColor,
  });

  final Meeting meeting;
  final String companyName;
  final String chipLabel;
  final Color companyColor;

  String get id => meeting.id;
  String get companyId => meeting.companyId;
  String get title => meeting.title;
  String get description => meeting.description;
  DateTime get scheduledAt => meeting.scheduledAt;
  DateTime get updatedAt => meeting.updatedAt;
  MeetingPriority get priority => meeting.priority;
  bool get isTeamMeeting => meeting.isTeamMeeting;
  String? get location => meeting.location;

  @override
  List<Object?> get props => [meeting, companyName, chipLabel, companyColor];
}

class CompanySummaryItem extends Equatable {
  const CompanySummaryItem({
    required this.companyId,
    required this.name,
    required this.chipLabel,
    required this.color,
    required this.meetingCount,
    required this.todayCount,
    required this.highPriorityCount,
  });

  final String companyId;
  final String name;
  final String chipLabel;
  final Color color;
  final int meetingCount;
  final int todayCount;
  final int highPriorityCount;

  @override
  List<Object?> get props => [
    companyId,
    name,
    chipLabel,
    color,
    meetingCount,
    todayCount,
    highPriorityCount,
  ];
}

enum BossDashboardStatus { initial, loading, ready, error }

class BossDashboardState extends Equatable {
  const BossDashboardState({
    this.status = BossDashboardStatus.initial,
    this.allMeetings = const [],
    this.selectedCompanyId,
    this.searchQuery = '',
    this.quickFilter = BossQuickFilter.all,
    this.unreadNotifications = 3,
    this.errorMessage,
  });

  final BossDashboardStatus status;
  final List<PortfolioMeeting> allMeetings;
  final String? selectedCompanyId;
  final String searchQuery;
  final BossQuickFilter quickFilter;
  final int unreadNotifications;
  final String? errorMessage;

  bool get isLoading => status == BossDashboardStatus.loading;

  List<PortfolioMeeting> get scopedMeetings {
    var list = allMeetings;
    final companyId = selectedCompanyId;
    if (companyId != null) {
      list = list.where((m) => m.companyId == companyId).toList();
    }

    final q = searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where(
            (m) =>
                m.title.toLowerCase().contains(q) ||
                m.description.toLowerCase().contains(q) ||
                m.companyName.toLowerCase().contains(q) ||
                (m.location?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    switch (quickFilter) {
      case BossQuickFilter.all:
        break;
      case BossQuickFilter.today:
        list = list
            .where(
              (m) =>
                  !m.scheduledAt.isBefore(start) && m.scheduledAt.isBefore(end),
            )
            .toList();
      case BossQuickFilter.upcoming:
        list = list.where((m) => m.scheduledAt.isAfter(now)).toList();
      case BossQuickFilter.highPriority:
        list = list
            .where(
              (m) =>
                  m.priority == MeetingPriority.high ||
                  m.priority == MeetingPriority.critical,
            )
            .toList();
      case BossQuickFilter.team:
        list = list.where((m) => m.isTeamMeeting).toList();
    }

    return list;
  }

  List<PortfolioMeeting> get todaysMeetings {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return scopedMeetings
        .where(
          (m) => !m.scheduledAt.isBefore(start) && m.scheduledAt.isBefore(end),
        )
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  List<PortfolioMeeting> get upcomingMeetings {
    final now = DateTime.now();
    return scopedMeetings.where((m) => m.scheduledAt.isAfter(now)).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  List<PortfolioMeeting> get highPriorityMeetings =>
      scopedMeetings
          .where(
            (m) =>
                m.priority == MeetingPriority.high ||
                m.priority == MeetingPriority.critical,
          )
          .toList()
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

  List<PortfolioMeeting> get recentlyUpdated {
    final list = [...scopedMeetings]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list.take(6).toList();
  }

  List<PortfolioMeeting> get timeline =>
      [...scopedMeetings]
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

  BossDashboardState copyWith({
    BossDashboardStatus? status,
    List<PortfolioMeeting>? allMeetings,
    String? selectedCompanyId,
    bool clearCompanyFilter = false,
    String? searchQuery,
    BossQuickFilter? quickFilter,
    int? unreadNotifications,
    String? errorMessage,
    bool clearError = false,
  }) {
    return BossDashboardState(
      status: status ?? this.status,
      allMeetings: allMeetings ?? this.allMeetings,
      selectedCompanyId: clearCompanyFilter
          ? null
          : (selectedCompanyId ?? this.selectedCompanyId),
      searchQuery: searchQuery ?? this.searchQuery,
      quickFilter: quickFilter ?? this.quickFilter,
      unreadNotifications: unreadNotifications ?? this.unreadNotifications,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    status,
    allMeetings,
    selectedCompanyId,
    searchQuery,
    quickFilter,
    unreadNotifications,
    errorMessage,
  ];
}
