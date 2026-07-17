import 'package:equatable/equatable.dart';

import 'app_permission.dart';
import 'role_permission_catalog.dart';
import 'system_role.dart';

/// Immutable permission set for the signed-in user.
class PermissionSet extends Equatable {
  const PermissionSet({required this.role, required this.permissions});

  final SystemRole role;
  final Set<AppPermission> permissions;

  factory PermissionSet.forRole(SystemRole role) {
    return PermissionSet(
      role: role,
      permissions: RolePermissionCatalog.permissionsFor(role),
    );
  }

  factory PermissionSet.empty() =>
      const PermissionSet(role: SystemRole.employee, permissions: {});

  bool can(AppPermission permission) => permissions.contains(permission);

  bool canAny(Iterable<AppPermission> required) =>
      required.any(permissions.contains);

  bool canAll(Iterable<AppPermission> required) =>
      required.every(permissions.contains);

  /// Meeting create: EA/Manager use [createMeeting]; Team Lead uses team scope.
  bool get canCreateMeeting =>
      can(AppPermission.createMeeting) || can(AppPermission.createTeamMeeting);

  bool get canEditSomeMeeting =>
      can(AppPermission.editAnyMeeting) ||
      can(AppPermission.editOwnMeeting) ||
      can(AppPermission.editTeamMeeting);

  bool get canDeleteSomeMeeting =>
      can(AppPermission.deleteAnyMeeting) ||
      can(AppPermission.deleteOwnMeeting);

  @override
  List<Object?> get props => [role, permissions];
}

/// Context for resource-level meeting checks (own / team / any).
class MeetingAccessContext {
  const MeetingAccessContext({
    required this.createdByUserId,
    this.teamLeadId,
    this.isTeamMeeting = false,
    this.participantIds = const {},
  });

  final String createdByUserId;
  final String? teamLeadId;
  final bool isTeamMeeting;
  final Set<String> participantIds;
}

extension MeetingPermissionX on PermissionSet {
  bool canViewMeeting({
    required String currentUserId,
    required MeetingAccessContext meeting,
  }) {
    if (!can(AppPermission.viewMeetings)) return false;

    // Boss (view-only): sees every meeting scheduled for them.
    if (!canCreateMeeting) return true;

    // Team members: meetings they created (for the Boss).
    if (meeting.createdByUserId == currentUserId) return true;

    return meeting.participantIds.contains(currentUserId);
  }

  bool canRespondToMeeting({
    required String currentUserId,
    required MeetingAccessContext meeting,
  }) {
    return can(AppPermission.acceptDeclineInvitation) &&
        meeting.participantIds.contains(currentUserId);
  }

  bool canEditMeeting({
    required String currentUserId,
    required MeetingAccessContext meeting,
  }) {
    if (can(AppPermission.editAnyMeeting)) return true;
    if (can(AppPermission.editOwnMeeting) &&
        meeting.createdByUserId == currentUserId) {
      return true;
    }
    if (can(AppPermission.editTeamMeeting) &&
        meeting.isTeamMeeting &&
        (meeting.teamLeadId == currentUserId ||
            meeting.createdByUserId == currentUserId)) {
      return true;
    }
    return false;
  }

  bool canDeleteMeeting({
    required String currentUserId,
    required MeetingAccessContext meeting,
  }) {
    if (can(AppPermission.deleteAnyMeeting)) return true;
    if (can(AppPermission.deleteOwnMeeting) &&
        meeting.createdByUserId == currentUserId) {
      return true;
    }
    return false;
  }
}
