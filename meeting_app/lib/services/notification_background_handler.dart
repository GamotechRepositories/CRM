import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../core/utils/logger.dart';
import '../firebase_options.dart';
import '../utils/notification_constants.dart';

/// Top-level background FCM handler — must not be a class method.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    AppLogger.info(
      'Background notification received: ${message.messageId ?? 'unknown'}',
      tag: NotificationConstants.logTag,
    );
  } catch (error, stack) {
    AppLogger.error(
      'Background handler failed',
      tag: NotificationConstants.logTag,
      error: error,
    );
    Error.throwWithStackTrace(error, stack);
  }
}
