import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/rbac/app_permission.dart';
import '../../../../core/rbac/permission_set.dart';
import '../../domain/entities/meeting.dart';
import '../../domain/repositories/meeting_repository.dart';
import '../states/meetings_state.dart';

class MeetingsController extends StateNotifier<MeetingsState> {
  MeetingsController({
    required MeetingRepository repository,
    required PermissionSet permissions,
    required String? currentUserId,
  }) : _repository = repository,
       _permissions = permissions,
       _currentUserId = currentUserId,
       super(const MeetingsState());

  final MeetingRepository _repository;
  final PermissionSet _permissions;
  final String? _currentUserId;

  Future<void> load(String? companyId) async {
    if (!_permissions.can(AppPermission.viewMeetings)) {
      state = state.copyWith(
        status: MeetingsStatus.error,
        errorMessage: 'You do not have permission to view meetings',
      );
      return;
    }

    state = state.copyWith(status: MeetingsStatus.loading, clearError: true);
    // Central admin meetings — one list for Boss + team (no company switch).
    final result = await _repository.getAll();
    state = switch (result) {
      Success(:final data) => state.copyWith(
        status: MeetingsStatus.success,
        meetings: _visibleMeetings(data),
      ),
      Error(:final failure) => state.copyWith(
        status: MeetingsStatus.error,
        errorMessage: failure.message,
      ),
    };
  }

  List<Meeting> _visibleMeetings(List<Meeting> meetings) {
    final userId = _currentUserId;
    if (userId == null) return const [];

    return meetings.where((meeting) {
      return _permissions.canViewMeeting(
        currentUserId: userId,
        meeting: _accessContext(meeting),
      );
    }).toList();
  }

  MeetingAccessContext _accessContext(Meeting meeting) {
    return MeetingAccessContext(
      createdByUserId: meeting.createdByUserId,
      teamLeadId: meeting.teamLeadId,
      isTeamMeeting: meeting.isTeamMeeting,
      participantIds: meeting.participants.map((p) => p.userId).toSet(),
    );
  }

  Future<bool> createMeeting(Meeting meeting) async {
    if (!_permissions.canCreateMeeting) {
      state = state.copyWith(errorMessage: 'Missing create meeting permission');
      return false;
    }
    if (_permissions.can(AppPermission.createTeamMeeting) &&
        !_permissions.can(AppPermission.createMeeting) &&
        !meeting.isTeamMeeting) {
      state = state.copyWith(
        errorMessage: 'Team leads can only create team meetings',
      );
      return false;
    }

    return _persistCreate(meeting);
  }

  Future<bool> updateMeeting(Meeting meeting) async {
    final userId = _currentUserId;
    if (userId == null) return false;

    final access = MeetingAccessContext(
      createdByUserId: meeting.createdByUserId,
      teamLeadId: meeting.teamLeadId,
      isTeamMeeting: meeting.isTeamMeeting,
      participantIds: meeting.participants.map((p) => p.userId).toSet(),
    );
    final allowed = _permissions.canEditMeeting(
      currentUserId: userId,
      meeting: access,
    );

    if (!allowed) {
      state = state.copyWith(errorMessage: 'Missing edit meeting permission');
      return false;
    }

    return _persistUpdate(meeting);
  }

  Future<bool> updateStatus(Meeting meeting, MeetingStatus status) async {
    if (!_permissions.can(AppPermission.updateMeetingStatus) &&
        !_permissions.can(AppPermission.editAnyMeeting)) {
      final userId = _currentUserId;
      if (userId == null) return false;
      final canEdit = _permissions.canEditMeeting(
        currentUserId: userId,
        meeting: MeetingAccessContext(
          createdByUserId: meeting.createdByUserId,
          teamLeadId: meeting.teamLeadId,
          isTeamMeeting: meeting.isTeamMeeting,
        ),
      );
      if (!canEdit) {
        state = state.copyWith(errorMessage: 'Cannot update meeting status');
        return false;
      }
    }
    return _persistUpdate(
      meeting.copyWith(status: status, updatedAt: DateTime.now()),
    );
  }

  Future<bool> respondToInvitation({
    required Meeting meeting,
    required InvitationResponse response,
  }) async {
    if (!_permissions.can(AppPermission.acceptDeclineInvitation)) {
      state = state.copyWith(errorMessage: 'Cannot respond to invitations');
      return false;
    }
    final userId = _currentUserId;
    if (userId == null) return false;

    if (!_permissions.canRespondToMeeting(
      currentUserId: userId,
      meeting: _accessContext(meeting),
    )) {
      state = state.copyWith(
        errorMessage: 'You are not invited to this meeting',
      );
      return false;
    }

    final participants = meeting.participants.map((p) {
      if (p.userId == userId) return p.copyWith(response: response);
      return p;
    }).toList();

    return _persistUpdate(
      meeting.copyWith(participants: participants, updatedAt: DateTime.now()),
    );
  }

  Future<bool> deleteMeeting(Meeting meeting) async {
    final userId = _currentUserId;
    if (userId == null) return false;

    final allowed = _permissions.canDeleteMeeting(
      currentUserId: userId,
      meeting: MeetingAccessContext(
        createdByUserId: meeting.createdByUserId,
        teamLeadId: meeting.teamLeadId,
        isTeamMeeting: meeting.isTeamMeeting,
        participantIds: meeting.participants.map((p) => p.userId).toSet(),
      ),
    );
    if (!allowed) {
      state = state.copyWith(errorMessage: 'Missing delete meeting permission');
      return false;
    }

    state = state.copyWith(isMutating: true, clearError: true);
    final result = await _repository.delete(meeting.id);
    return switch (result) {
      Success() => () {
        state = state.copyWith(
          isMutating: false,
          meetings: state.meetings.where((m) => m.id != meeting.id).toList(),
        );
        return true;
      }(),
      Error(:final failure) => () {
        state = state.copyWith(
          isMutating: false,
          errorMessage: failure.message,
        );
        return false;
      }(),
    };
  }

  Future<bool> _persistCreate(Meeting meeting) async {
    state = state.copyWith(isMutating: true, clearError: true);
    final result = await _repository.create(meeting);
    return switch (result) {
      Success() => () {
        state = state.copyWith(
          isMutating: false,
          meetings: [...state.meetings, meeting]
            ..sort((a, b) => a.startAt.compareTo(b.startAt)),
          status: MeetingsStatus.success,
        );
        return true;
      }(),
      Error(:final failure) => () {
        state = state.copyWith(
          isMutating: false,
          errorMessage: failure.message,
        );
        return false;
      }(),
    };
  }

  Future<bool> _persistUpdate(Meeting meeting) async {
    state = state.copyWith(isMutating: true, clearError: true);
    final result = await _repository.update(meeting);
    return switch (result) {
      Success() => () {
        final next =
            state.meetings.map((m) => m.id == meeting.id ? meeting : m).toList()
              ..sort((a, b) => a.startAt.compareTo(b.startAt));
        state = state.copyWith(
          isMutating: false,
          meetings: next,
          status: MeetingsStatus.success,
        );
        return true;
      }(),
      Error(:final failure) => () {
        state = state.copyWith(
          isMutating: false,
          errorMessage: failure.message,
        );
        return false;
      }(),
    };
  }
}
