import 'package:flutter/widgets.dart';

/// Registers per-tab [ScrollController]s so re-tapping a tab scrolls to top.
abstract final class TabScrollRegistry {
  static final Map<int, ScrollController> _controllers = {};

  static void register(int tabIndex, ScrollController controller) {
    _controllers[tabIndex] = controller;
  }

  static void unregister(int tabIndex, ScrollController controller) {
    if (_controllers[tabIndex] == controller) {
      _controllers.remove(tabIndex);
    }
  }

  static ScrollController? controllerFor(int tabIndex) =>
      _controllers[tabIndex];

  /// Scrolls the tab's controller to top; retries if not attached yet.
  static Future<void> scrollToTop(int tabIndex, {int attempt = 0}) async {
    final controller = _controllers[tabIndex];
    if (controller == null) return;

    if (controller.hasClients) {
      await controller.animateTo(
        0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    if (attempt >= 6) return;
    await Future<void>.delayed(const Duration(milliseconds: 32));
    await scrollToTop(tabIndex, attempt: attempt + 1);
  }
}
