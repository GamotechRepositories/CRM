import 'package:flutter/material.dart';

/// Shared date/time pickers for meeting scheduling.
///
/// Always shows a **12-hour clock with AM/PM**, regardless of the device's
/// 24-hour system setting (some phones otherwise hide AM/PM).
abstract final class MeetingPickers {
  static Widget _wrapPicker(BuildContext context, Widget? child) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.noScaling,
        alwaysUse24HourFormat: false,
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }

  static Future<DateTime?> pickDate(
    BuildContext context, {
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
    String? helpText,
  }) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: helpText,
      builder: _wrapPicker,
    );
  }

  static Future<TimeOfDay?> pickTime(
    BuildContext context, {
    required TimeOfDay initialTime,
    String? helpText,
  }) {
    return showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: helpText,
      initialEntryMode: TimePickerEntryMode.dial,
      builder: _wrapPicker,
    );
  }
}
