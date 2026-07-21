import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../core/config/env_config.dart';
import '../core/utils/logger.dart';
import '../firebase_options.dart';
import '../models/notification_model.dart';
import '../utils/notification_constants.dart';
import 'local_notification_service.dart';
import 'notification_background_handler.dart';
import 'notification_navigator.dart';

typedef AuthTokenProvider = String? Function();

/// Central FCM service — permissions, tokens, foreground/background handling.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final LocalNotificationService _local = LocalNotificationService.instance;

  bool _initialized = false;
  bool _listenersAttached = false;
  AuthTokenProvider? _authTokenProvider;
  StreamSubscription<String>? _tokenRefreshSubscription;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      AppLogger.info(
        'Firebase initialized',
        tag: NotificationConstants.logTag,
      );
    } catch (error, stack) {
      AppLogger.error(
        'Firebase initialization failed',
        tag: NotificationConstants.logTag,
        error: error,
      );
      Error.throwWithStackTrace(error, stack);
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _local.initialize();
    await _attachListeners();

    _initialized = true;
  }

  void bindAuthTokenProvider(AuthTokenProvider provider) {
    _authTokenProvider = provider;
  }

  Future<bool> requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (granted) {
        AppLogger.info(
          'Permission granted (${settings.authorizationStatus.name})',
          tag: NotificationConstants.logTag,
        );
      } else {
        AppLogger.warning(
          'Permission denied (${settings.authorizationStatus.name})',
          tag: NotificationConstants.logTag,
        );
      }

      if (!kIsWeb && Platform.isAndroid) {
        final androidGranted = await _local.requestAndroidPermission();
        if (androidGranted) {
          AppLogger.info(
            'Android POST_NOTIFICATIONS granted',
            tag: NotificationConstants.logTag,
          );
        }
      }

      return granted;
    } catch (error) {
      AppLogger.error(
        'Notification permission request failed',
        tag: NotificationConstants.logTag,
        error: error,
      );
      return false;
    }
  }

  Future<String?> getFCMToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null || token.trim().isEmpty) {
        AppLogger.warning(
          'FCM token is null or empty',
          tag: NotificationConstants.logTag,
        );
        return null;
      }
      AppLogger.info(
        'FCM token generated (${token.length} chars)',
        tag: NotificationConstants.logTag,
      );
      return token;
    } catch (error) {
      AppLogger.error(
        'Failed to get FCM token',
        tag: NotificationConstants.logTag,
        error: error,
      );
      return null;
    }
  }

  Future<String?> refreshToken() async {
    try {
      await _messaging.deleteToken();
      final token = await getFCMToken();
      if (token != null) {
        await _registerTokenWithBackend(token);
      }
      return token;
    } catch (error) {
      AppLogger.error(
        'Token refresh failed',
        tag: NotificationConstants.logTag,
        error: error,
      );
      return null;
    }
  }

  /// Call after login when an auth token is available.
  Future<void> syncDeviceTokenAfterLogin() async {
    final token = await getFCMToken();
    if (token == null) return;
    await _registerTokenWithBackend(token);
  }

  /// Stop listening and clear push registration on logout.
  Future<void> onLogout() async {
    try {
      await _messaging.deleteToken();
      AppLogger.info('FCM token deleted on logout', tag: NotificationConstants.logTag);
    } catch (error) {
      AppLogger.warning(
        'Failed to delete FCM token on logout',
        tag: NotificationConstants.logTag,
      );
    }
  }

  Future<void> _attachListeners() async {
    if (_listenersAttached) return;

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen(
      (token) async {
        AppLogger.info('Token refreshed', tag: NotificationConstants.logTag);
        await _registerTokenWithBackend(token);
      },
      onError: (Object error) {
        AppLogger.error(
          'Token refresh stream error',
          tag: NotificationConstants.logTag,
          error: error,
        );
      },
    );

    _listenersAttached = true;
  }

  Future<void> handleInitialMessage() async {
    try {
      final message = await _messaging.getInitialMessage();
      if (message == null) return;
      AppLogger.info(
        'App opened from terminated notification',
        tag: NotificationConstants.logTag,
      );
      _handleRemoteOpen(message);
    } catch (error) {
      AppLogger.error(
        'getInitialMessage failed',
        tag: NotificationConstants.logTag,
        error: error,
      );
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    AppLogger.info(
      'Notification received (foreground) · id=${message.messageId}',
      tag: NotificationConstants.logTag,
    );

    final notification = AppNotification.fromRemoteMessage(message);
    final title = notification.title.trim().isEmpty
        ? 'Meeting update'
        : notification.title;
    final body = notification.body.trim().isEmpty
        ? 'You have a new notification'
        : notification.body;

    unawaited(
      _local.showNotification(
        id: message.hashCode,
        title: title,
        body: body,
        payload: notification.rawPayload.isEmpty
            ? message.data
            : notification.rawPayload,
      ),
    );
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    AppLogger.info(
      'Notification clicked (background)',
      tag: NotificationConstants.logTag,
    );
    _handleRemoteOpen(message);
  }

  void _handleRemoteOpen(RemoteMessage message) {
    final notification = AppNotification.fromRemoteMessage(message);
    NotificationNavigator.handle(notification);
  }

  Future<void> _registerTokenWithBackend(String deviceToken) async {
    final authToken = _authTokenProvider?.call();
    if (authToken == null || authToken.trim().isEmpty) {
      AppLogger.warning(
        'Skipping device register — not authenticated',
        tag: NotificationConstants.logTag,
      );
      return;
    }

    final platform = _platformName();
    final dio = Dio(
      BaseOptions(
        baseUrl: EnvConfig.adminBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ),
    );

    try {
      await dio.post<void>(
        NotificationConstants.deviceRegisterPath,
        data: {
          'deviceToken': deviceToken,
          'platform': platform,
        },
      );
      AppLogger.info(
        'Device token registered ($platform)',
        tag: NotificationConstants.logTag,
      );
    } on DioException catch (error) {
      AppLogger.error(
        'Device register failed · ${error.response?.statusCode}',
        tag: NotificationConstants.logTag,
        error: error.message,
      );
    } catch (error) {
      AppLogger.error(
        'Device register failed',
        tag: NotificationConstants.logTag,
        error: error,
      );
    }
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }
}
