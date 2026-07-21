import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/router/route_names.dart';
import '../core/utils/logger.dart';
import '../models/notification_model.dart';
import '../utils/notification_constants.dart';

/// Routes notification taps to in-app destinations (deep links).
abstract final class NotificationNavigator {
  static GlobalKey<NavigatorState>? _navigatorKey;

  static void bind(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
  }

  static void handle(AppNotification notification) {
    AppLogger.info(
      'Notification clicked · type=${notification.type} meetingId=${notification.meetingId}',
      tag: NotificationConstants.logTag,
    );

    if (!notification.isMeetingDeepLink) return;

    final context = _navigatorKey?.currentContext;
    if (context == null) {
      AppLogger.warning(
        'Navigator not ready — cannot open meeting ${notification.meetingId}',
        tag: NotificationConstants.logTag,
      );
      return;
    }

    context.push(RoutePaths.meetingDetailsPath(notification.meetingId!.trim()));
  }
}
