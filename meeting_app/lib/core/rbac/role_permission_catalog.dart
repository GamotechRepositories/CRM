import 'app_permission.dart';
import 'system_role.dart';

/// Simple two-role matrix for the meeting app.
///
/// - Boss (CEO): view meetings created for them
/// - Team (EA / Coordinator / etc.): create & manage meetings for the Boss
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
