import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/rbac/app_permission.dart';
import '../../../../core/rbac/permission_set.dart';
import '../../../meetings/domain/repositories/meeting_repository.dart';
import '../../data/ea_workflow_demo_factory.dart';
import '../../domain/entities/meeting_invitation.dart';
import '../../domain/entities/meeting_request.dart';
import '../states/ea_dashboard_state.dart';

class EaDashboardController extends StateNotifier<EaDashboardState> {
  EaDashboardController({
    required MeetingRepository meetingRepository,
    required PermissionSet permissions,
  }) : _meetings = meetingRepository,
       _permissions = permissions,
       super(const EaDashboardState());

  final MeetingRepository _meetings;
  final PermissionSet _permissions;

  Future<void> load(String? companyId) async {
    if (!_permissions.can(AppPermission.viewDashboard) ||
        !_permissions.can(AppPermission.viewMeetings)) {
      state = state.copyWith(
        status: EaDashboardStatus.error,
        errorMessage: 'Missing dashboard access',
      );
      return;
    }

    if (companyId == null || companyId.isEmpty) {
      state = state.copyWith(
        status: EaDashboardStatus.ready,
        meetings: const [],
        invitations: const [],
        requests: const [],
        activity: const [],
      );
      return;
    }

    state = state.copyWith(status: EaDashboardStatus.loading, clearError: true);

    final result = await _meetings.getByCompany(companyId);
    final now = DateTime.now();

    switch (result) {
      case Error(:final failure):
        state = state.copyWith(
          status: EaDashboardStatus.error,
          errorMessage: failure.message,
        );
      case Success(:final data):
        state = state.copyWith(
          status: EaDashboardStatus.ready,
          meetings: data,
          invitations: EaWorkflowDemoFactory.invitations(
            companyId: companyId,
            now: now,
          ),
          requests: EaWorkflowDemoFactory.requests(
            companyId: companyId,
            now: now,
          ),
          activity: EaWorkflowDemoFactory.activity(
            companyId: companyId,
            now: now,
          ),
          selectedDay: DateTime(now.year, now.month, now.day),
        );
    }
  }

  void selectDay(DateTime day) {
    state = state.copyWith(selectedDay: DateTime(day.year, day.month, day.day));
  }

  void acceptInvitation(String id) {
    state = state.copyWith(
      invitations: state.invitations
          .map(
            (i) => i.id == id
                ? MeetingInvitation(
                    id: i.id,
                    companyId: i.companyId,
                    title: i.title,
                    fromName: i.fromName,
                    scheduledAt: i.scheduledAt,
                    status: InvitationStatus.accepted,
                    location: i.location,
                  )
                : i,
          )
          .toList(),
    );
  }

  void declineInvitation(String id) {
    state = state.copyWith(
      invitations: state.invitations
          .map(
            (i) => i.id == id
                ? MeetingInvitation(
                    id: i.id,
                    companyId: i.companyId,
                    title: i.title,
                    fromName: i.fromName,
                    scheduledAt: i.scheduledAt,
                    status: InvitationStatus.declined,
                    location: i.location,
                  )
                : i,
          )
          .toList(),
    );
  }

  void approveRequest(String id) {
    state = state.copyWith(
      requests: state.requests
          .map(
            (r) => r.id == id
                ? MeetingRequest(
                    id: r.id,
                    companyId: r.companyId,
                    title: r.title,
                    requesterName: r.requesterName,
                    preferredAt: r.preferredAt,
                    status: MeetingRequestStatus.approved,
                    createdAt: r.createdAt,
                    notes: r.notes,
                  )
                : r,
          )
          .toList(),
    );
  }

  void rejectRequest(String id) {
    state = state.copyWith(
      requests: state.requests
          .map(
            (r) => r.id == id
                ? MeetingRequest(
                    id: r.id,
                    companyId: r.companyId,
                    title: r.title,
                    requesterName: r.requesterName,
                    preferredAt: r.preferredAt,
                    status: MeetingRequestStatus.rejected,
                    createdAt: r.createdAt,
                    notes: r.notes,
                  )
                : r,
          )
          .toList(),
    );
  }
}
