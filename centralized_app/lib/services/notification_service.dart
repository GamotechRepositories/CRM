import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

enum NotificationChannel { tasks, attendance }

/// Thin wrapper over `flutter_local_notifications` (Android only).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _canScheduleExact = false;
  late tz.Location _ist;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> init() async {
    if (_initialized || !_supported) return;
    tz_data.initializeTimeZones();
    _ist = tz.getLocation('Asia/Kolkata');
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _initialized = true;
  }

  /// Android 13+ runtime notification permission.
  Future<void> requestPermissions() async {
    if (!_supported) return;
    await init();
    try {
      await _android?.requestNotificationsPermission();
      _canScheduleExact = await _android?.canScheduleExactNotifications() ?? false;
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
    }
  }

  NotificationDetails _details(NotificationChannel channel) {
    final android = switch (channel) {
      NotificationChannel.tasks => const AndroidNotificationDetails(
          'crm_tasks',
          'Task assignments',
          channelDescription: 'Alerts when a new task is assigned to you',
          importance: Importance.high,
          priority: Priority.high,
        ),
      NotificationChannel.attendance => const AndroidNotificationDetails(
          'crm_attendance',
          'Attendance reminders',
          channelDescription: 'Check-in, check-out and break reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
    };
    return NotificationDetails(android: android);
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
    NotificationChannel channel = NotificationChannel.attendance,
  }) async {
    if (!_supported) return;
    await init();
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: _details(channel),
      );
    } catch (e) {
      debugPrint('Notification show failed: $e');
    }
  }

  /// Schedules a one-shot notification at [when] (any timezone; converted to IST).
  Future<void> scheduleAt({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    NotificationChannel channel = NotificationChannel.attendance,
  }) async {
    if (!_supported) return;
    await init();
    if (!when.isAfter(DateTime.now())) return;
    final at = tz.TZDateTime.from(when, _ist);
    Future<void> schedule(AndroidScheduleMode mode) => _plugin.zonedSchedule(
          id: id,
          scheduledDate: at,
          notificationDetails: _details(channel),
          androidScheduleMode: mode,
          title: title,
          body: body,
        );
    try {
      await schedule(_canScheduleExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle);
    } catch (e) {
      // Exact alarm permission can be revoked at any time on Android 14+.
      try {
        await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
      } catch (e2) {
        debugPrint('Notification schedule failed: $e2');
      }
    }
  }

  Future<void> cancel(int id) async {
    if (!_supported || !_initialized) return;
    try {
      await _plugin.cancel(id: id);
    } catch (_) {}
  }

  Future<void> cancelAll() async {
    if (!_supported || !_initialized) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}
