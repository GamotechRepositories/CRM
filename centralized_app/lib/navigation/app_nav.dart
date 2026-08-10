import 'package:flutter/widgets.dart';

/// Lets nested pages switch the app shell route.
class AppNavScope extends InheritedWidget {
  const AppNavScope({
    super.key,
    required this.goTo,
    required super.child,
  });

  final void Function(String path) goTo;

  static void navigate(BuildContext context, String path) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppNavScope>();
    scope?.goTo(path);
  }

  @override
  bool updateShouldNotify(AppNavScope oldWidget) => goTo != oldWidget.goTo;
}
