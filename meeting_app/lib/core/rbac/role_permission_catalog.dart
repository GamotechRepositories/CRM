import 'app_permission.dart';
import 'system_role.dart';

/// Role matrix for the meeting app.
///
/// - Boss (CEO): sees approved meetings only; RSVP / reschedule
/// - Meeting Coordinator: Boss-like UI; can create for Boss; approve team drafts; reschedule
/// - Team (EA / etc.): create meetings (pending until Coordinator approves)
abstract final class RolePermissionCatalog {
  static const Map<SystemRole, Set<AppPermission>> matrix = {
    SystemRole.boss: {
      AppPermission.viewDashboard,
      AppPermission.viewSettings,
      AppPermission.viewMeetingsNav,
      AppPermission.viewMeetings,
      AppPermission.receiveNotifications,
      AppPermission.downloadAttachments,
      AppPermission.joinMeeting,
      AppPermission.acceptDeclineInvitation,
      AppPermission.rescheduleMeeting,
    },
    SystemRole.meetingCoordinator: {
      AppPermission.viewDashboard,
      AppPermission.viewSettings,
      AppPermission.viewMeetingsNav,
      AppPermission.viewMeetings,
      AppPermission.receiveNotifications,
      AppPermission.createMeeting,
      AppPermission.editOwnMeeting,
      AppPermission.deleteOwnMeeting,
      AppPermission.downloadAttachments,
      AppPermission.uploadAttachments,
      AppPermission.joinMeeting,
      AppPermission.acceptDeclineInvitation,
      AppPermission.rescheduleMeeting,
      AppPermission.approveMeeting,
      AppPermission.editAnyMeeting,
      AppPermission.updateMeetingStatus,
    },
    SystemRole.executiveAssistant: {
      AppPermission.viewDashboard,
      AppPermission.viewSettings,
      AppPermission.viewMeetingsNav,
      AppPermission.viewMeetings,
      AppPermission.receiveNotifications,
      AppPermission.createMeeting,
      AppPermission.editOwnMeeting,
      AppPermission.deleteOwnMeeting,
      AppPermission.rescheduleMeeting,
      AppPermission.uploadAttachments,
      AppPermission.downloadAttachments,
      AppPermission.updateMeetingStatus,
    },
    // Unused in simplified app — kept so RoleResolver never crashes.
    SystemRole.manager: {
      AppPermission.viewDashboard,
      AppPermission.viewSettings,
      AppPermission.viewMeetings,
    },
    SystemRole.teamLead: {
      AppPermission.viewDashboard,
      AppPermission.viewSettings,
      AppPermission.viewMeetings,
    },
    SystemRole.employee: {
      AppPermission.viewDashboard,
      AppPermission.viewSettings,
      AppPermission.viewMeetings,
    },
  };

  static Set<AppPermission> permissionsFor(SystemRole role) =>
      Set.unmodifiable(matrix[role] ?? const <AppPermission>{});
}
