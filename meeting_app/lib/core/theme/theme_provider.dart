import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/storage_keys.dart';
import '../storage/hive_service.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(ref.watch(hiveServiceProvider)),
);

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this._hive) : super(_loadThemeMode(_hive));

  final HiveService _hive;

  static ThemeMode _loadThemeMode(HiveService hive) {
    final stored = hive.get<String>(StorageKeys.themeMode);
    return switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.light,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _hive.put(StorageKeys.themeMode, value);
  }

  Future<void> toggleDarkMode() async {
    // Prefer explicit dark/light so switch always feels instant.
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final currentlyDark = state == ThemeMode.dark ||
        (state == ThemeMode.system && brightness == Brightness.dark);
    await setThemeMode(currentlyDark ? ThemeMode.light : ThemeMode.dark);
  }
}
