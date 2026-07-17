/// Granular application permissions.
///
/// Screens and widgets must check [AppPermission] via the RBAC layer —
/// never compare role names inline.
enum AppPermission {
  // Shell / navigation
  viewDashboard,
  viewMeetingsNav,
  viewCompaniesNav,
  viewSettings,
  viewCalendar,
  receiveNotifications,

  // Multi-company
  switchCompany,
  viewCompanies,
  createCompany,
  editCompany,
  deleteCompany,

  // Employees
  viewEmployees,
  manageEmployees,

  // Meetings
  viewMeetings,
  createMeeting,
  createTeamMeeting,
  editAnyMeeting,
  editOwnMeeting,
  editTeamMeeting,
  deleteAnyMeeting,
  deleteOwnMeeting,
  rescheduleMeeting,
  inviteParticipants,
  uploadAttachments,
  downloadAttachments,
  updateMeetingStatus,
  acceptDeclineInvitation,
  joinMeeting,
}
