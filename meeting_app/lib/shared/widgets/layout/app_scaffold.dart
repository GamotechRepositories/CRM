import 'package:flutter/material.dart';

import '../../../core/responsive/responsive_layout.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../features/shell/presentation/widgets/flipkart_bottom_nav.dart';
import '../../../features/shell/presentation/widgets/shell_bottom_insets.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.drawer,
    this.backgroundColor,
    this.useSafeArea = true,
    this.padFloatingNav = false,
    this.maxContentWidth,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Widget? drawer;
  final Color? backgroundColor;
  final bool useSafeArea;

  /// Extra bottom padding so content clears the floating pill nav.
  final bool padFloatingNav;
  final double? maxContentWidth;

  @override
  Widget build(BuildContext context) {
    Widget content = body;

    if (maxContentWidth != null) {
      content = ResponsiveContainer(
        maxWidth: maxContentWidth!,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: content,
      );
    }

    if (useSafeArea) {
      content = SafeArea(
        bottom: !padFloatingNav,
        child: content,
      );
    }

    if (padFloatingNav) {
      content = Padding(
        padding: EdgeInsets.only(bottom: ShellBottomInsets.of(context)),
        child: content,
      );
    }

    Widget? fab = floatingActionButton;
    if (fab != null && padFloatingNav) {
      fab = Padding(
        padding: EdgeInsets.only(
          bottom: FlipkartBottomNav.barHeight + FlipkartBottomNav.bottomGap,
        ),
        child: fab,
      );
    }

    return Scaffold(
      appBar: appBar,
      drawer: drawer,
      backgroundColor:
          backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: fab,
      bottomNavigationBar: bottomNavigationBar,
      body: content,
    );
  }
}
