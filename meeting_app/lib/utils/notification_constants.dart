/// Shared constants for push / local notifications.
abstract final class NotificationConstants {
  static const String channelId = 'meeting_app_high_importance';
  static const String channelName = 'Meeting updates';
  static const String channelDescription =
      'Alerts for meetings, approvals, and schedule changes';

  static const String payloadTypeKey = 'type';
  static const String payloadMeetingIdKey = 'meetingId';

  static const String typeMeeting = 'meeting';

  static const String deviceRegisterPath = '/device/register';

  static const String logTag = 'FCM';
  static const String localLogTag = 'LocalNotifications';
}
