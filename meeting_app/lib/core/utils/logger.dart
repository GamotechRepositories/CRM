import 'package:flutter/foundation.dart';

abstract final class AppLogger {
  static void debug(String message, {String? tag}) {
    if (kDebugMode) {
      debugPrint('[${tag ?? 'App'}] $message');
    }
  }

  static void info(String message, {String? tag}) {
    if (kDebugMode) {
      debugPrint('[${tag ?? 'App'}] ℹ $message');
    }
  }

  static void warning(String message, {String? tag}) {
    if (kDebugMode) {
      debugPrint('[${tag ?? 'App'}] ⚠ $message');
    }
  }

  static void error(String message, {String? tag, Object? error}) {
    if (kDebugMode) {
      debugPrint(
        '[${tag ?? 'App'}] ✕ $message${error != null ? ': $error' : ''}',
      );
    }
  }
}
