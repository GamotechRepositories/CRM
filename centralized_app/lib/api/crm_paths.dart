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
  static const chatConversations = '/chat/conversations';
  static const uploadsPresign = '/uploads/presign';

  static String attendanceForEmployee(String employeeId) =>
      '/attendance/employee/$employeeId';
}
