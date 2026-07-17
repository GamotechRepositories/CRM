import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/rbac/app_permission.dart';
import '../../../../core/rbac/permission_set.dart';
import '../../../companies/domain/entities/company.dart';
import '../../../meetings/domain/entities/meeting.dart';
import '../../../meetings/domain/repositories/meeting_repository.dart';
import '../../../organization/domain/organization_constants.dart';
import '../states/boss_dashboard_state.dart';

class BossDashboardController extends StateNotifier<BossDashboardState> {
  BossDashboardController({
    required MeetingRepository meetingRepository,
    required PermissionSet permissions,
  }) : _meetings = meetingRepository,
       _permissions = permissions,
       super(const BossDashboardState());

  final MeetingRepository _meetings;
  final PermissionSet _permissions;

  Future<void> load(List<Company> companies) async {
    if (!_permissions.can(AppPermission.viewMeetings) &&
        !_permissions.can(AppPermission.viewDashboard)) {
      state = state.copyWith(
        status: BossDashboardStatus.error,
        errorMessage: 'Missing dashboard access',
      );
      return;
    }

    state = state.copyWith(
      status: BossDashboardStatus.loading,
      clearError: true,
    );

    final result = await _meetings.getAll();
    switch (result) {
      case Error(:final failure):
        state = state.copyWith(
          status: BossDashboardStatus.error,
          errorMessage: failure.message,
        );
      case Success(:final data):
        final companyIds = companies.map((c) => c.id).toSet();
        final chipById = {
          for (final spec in OrganizationConstants.demoCompanies)
            spec.id: spec.chipLabel,
        };
        final companyById = {for (final c in companies) c.id: c};

        final portfolio =
            data.where((m) => companyIds.contains(m.companyId)).map((m) {
              final company = companyById[m.companyId];
              return PortfolioMeeting(
                meeting: m,
                companyName: company?.name ?? 'Company',
                chipLabel: chipById[m.companyId] ?? company?.name ?? 'Company',
                companyColor: company?.color ?? const Color(0xFF1D4ED8),
              );
            }).toList()..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

        state = state.copyWith(
          status: BossDashboardStatus.ready,
          allMeetings: portfolio,
        );
    }
  }

  void selectCompany(String? companyId) {
    if (companyId == null) {
      state = state.copyWith(clearCompanyFilter: true);
    } else {
      state = state.copyWith(selectedCompanyId: companyId);
    }
  }

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setQuickFilter(BossQuickFilter filter) {
    state = state.copyWith(quickFilter: filter);
  }

  void clearNotifications() {
    state = state.copyWith(unreadNotifications: 0);
  }

  List<CompanySummaryItem> companySummaries(List<Company> companies) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final chipById = {
      for (final spec in OrganizationConstants.demoCompanies)
        spec.id: spec.chipLabel,
    };

    return companies.map((c) {
      final meetings = state.allMeetings
          .where((m) => m.companyId == c.id)
          .toList();
      return CompanySummaryItem(
        companyId: c.id,
        name: c.name,
        chipLabel: chipById[c.id] ?? c.name,
        color: c.color,
        meetingCount: meetings.length,
        todayCount: meetings
            .where(
              (m) =>
                  !m.scheduledAt.isBefore(start) && m.scheduledAt.isBefore(end),
            )
            .length,
        highPriorityCount: meetings
            .where(
              (m) =>
                  m.priority == MeetingPriority.high ||
                  m.priority == MeetingPriority.critical,
            )
            .length,
      );
    }).toList();
  }
}
