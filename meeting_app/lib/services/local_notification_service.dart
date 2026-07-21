import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/utils/logger.dart';
import '../models/notification_model.dart';
import '../utils/notification_constants.dart';
import 'notification_navigator.dart';

/// Displays foreground notifications and handles local notification taps.
class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              NotificationConstants.channelId,
              NotificationConstants.channelName,
              description: NotificationConstants.channelDescription,
              importance: Importance.high,
            ),
          );
    }

    _initialized = true;
    AppLogger.info(
      'Local notifications initialized',
      tag: NotificationConstants.localLogTag,
    );
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    final encodedPayload = payload == null ? null : jsonEncode(payload);

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationConstants.channelId,
          NotificationConstants.channelName,
          channelDescription: NotificationConstants.channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: encodedPayload,
    );

    AppLogger.debug(
      'Local notification shown · id=$id title=$title',
      tag: NotificationConstants.localLogTag,
    );
  }

  Future<void> cancelNotification(int id) => _plugin.cancel(id: id);

  Future<void> cancelAll() => _plugin.cancelAll();

  Future<bool> requestAndroidPermission() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission() ??
        false;
  }

  void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.trim().isEmpty) return;

    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return;
      final notification = AppNotification.fromPayload(
        Map<String, dynamic>.from(decoded),
      );
      NotificationNavigator.handle(notification);
    } catch (error) {
      AppLogger.error(
        'Failed to parse local notification payload',
        tag: NotificationConstants.localLogTag,
        error: error,
      );
    }
  }
}
