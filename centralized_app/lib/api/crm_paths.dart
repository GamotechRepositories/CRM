/// Common CRM path helpers (mirrors web frontend axios routes).
class CrmPaths {
  static const authLogin = '/auth/login';
  static const employees = '/employees';
  static const employeeProfile = '/employees';
  static const employeeProfilePhoto = '/employees'; // + /:id/profile-photo
  static const clients = '/clients';
  static const projects = '/projects';
  static const projectsMy = '/projects/my-projects';
  static const employeesAvailability = '/employees/availability';
  static const tasks = '/tasks';
  static const leads = '/leads';
  static const billing = '/billing';
  static const leave = '/leave';
  static const attendance = '/attendance';
  static const attendanceToday = '/attendance/today';
  static const attendanceCheckIn = '/attendance/check-in';
  static const attendanceCheckOut = '/attendance/check-out';
  static const attendanceBreakStart = '/attendance/break/start';
  static const attendanceBreakEnd = '/attendance/break/end';
  static const attendanceMeetingStart = '/attendance/meeting/start';
  static const attendanceMeetingEnd = '/attendance/meeting/end';
  static const attendanceByMonth = '/attendance/by-month';
  static const properties = '/properties';
  static const announcements = '/announcements';
  static const siteVisits = '/site-visits';
  static const siteVisitsTravelTimeline = '/site-visits/travel-timeline';
  static const siteVisitsStartJourney = '/site-visits/start-journey';
  static const siteVisitsEndJourney = '/site-visits/end-journey';
  static const siteVisitsAllocateExpense = '/site-visits/allocate-travel-expense';

  static String siteVisitCheckIn(String id) => '/site-visits/$id/check-in';
  static String siteVisitCheckOut(String id) => '/site-visits/$id/check-out';
  static const chatConversations = '/chat/conversations';
  static const chatEmployees = '/chat/employees';
  static const chatIntegration = '/chat/integration';
  static const uploadsPresign = '/uploads/presign';

  static String chatMessages(String conversationId) =>
      '/chat/conversations/$conversationId/messages';

  static String chatRead(String conversationId) =>
      '/chat/conversations/$conversationId/read';

  static String chatPolls(String conversationId) =>
      '/chat/conversations/$conversationId/polls';

  static String chatVote(String messageId) => '/chat/messages/$messageId/vote';

  static String attendanceForEmployee(String employeeId) =>
      '/attendance/employee/$employeeId';
}
