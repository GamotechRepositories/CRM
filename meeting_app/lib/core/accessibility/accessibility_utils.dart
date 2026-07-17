import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../constants/app_constants.dart';

abstract final class AccessibilityUtils {
  /// Caps system text scaling so large accessibility fonts don't break layouts.
  ///
  /// Keep [minScaleFactor] below 1.0. Material widgets (date picker, nav bar)
  /// re-clamp with `maxScaleFactor: 1.0`; if our min is already 1.0, Flutter
  /// asserts `maxScale > minScale` and crashes.
  static Widget clampTextScale({
    required Widget child,
    double maxScale = AppConstants.maxTextScaleFactor,
  }) {
    return MediaQuery.withClampedTextScaling(
      minScaleFactor: 0.85,
      maxScaleFactor: maxScale,
      child: child,
    );
  }

  static Widget announce({
    required String label,
    required Widget child,
    bool button = false,
    bool header = false,
  }) {
    return Semantics(
      label: label,
      button: button,
      header: header,
      child: child,
    );
  }

  static void announceForAccessibility(BuildContext context, String message) {
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      TextDirection.ltr,
    );
  }
}
