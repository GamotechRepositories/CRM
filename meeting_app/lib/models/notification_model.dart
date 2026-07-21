import 'package:equatable/equatable.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../utils/notification_constants.dart';

/// Normalized in-app notification payload from FCM or local taps.
class AppNotification extends Equatable {
  const AppNotification({
    required this.title,
    required this.body,
    this.type,
    this.meetingId,
    this.rawPayload = const {},
  });

  final String title;
  final String body;
  final String? type;
  final String? meetingId;
  final Map<String, dynamic> rawPayload;

  bool get isMeetingDeepLink =>
      type == NotificationConstants.typeMeeting &&
      meetingId != null &&
      meetingId!.trim().isNotEmpty;

  factory AppNotification.fromRemoteMessage(RemoteMessage message) {
    final data = _normalizeData(message.data);
    return AppNotification(
      title: message.notification?.title ?? data['title']?.toString() ?? '',
      body: message.notification?.body ?? data['body']?.toString() ?? '',
      type: data[NotificationConstants.payloadTypeKey]?.toString(),
      meetingId: data[NotificationConstants.payloadMeetingIdKey]?.toString(),
      rawPayload: data,
    );
  }

  factory AppNotification.fromPayload(Map<String, dynamic> payload) {
    final data = _normalizeData(payload);
    return AppNotification(
      title: data['title']?.toString() ?? '',
      body: data['body']?.toString() ?? '',
      type: data[NotificationConstants.payloadTypeKey]?.toString(),
      meetingId: data[NotificationConstants.payloadMeetingIdKey]?.toString(),
      rawPayload: data,
    );
  }

  static Map<String, dynamic> _normalizeData(Map<String, dynamic> data) {
    return Map<String, dynamic>.from(data);
  }

  @override
  List<Object?> get props => [title, body, type, meetingId, rawPayload];
}
