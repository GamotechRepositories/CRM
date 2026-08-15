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
    this.pinAppBar = false,
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
  final bool pinAppBar;

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
        top: appBar == null,
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

    final effectiveBg =
        backgroundColor ?? Theme.of(context).scaffoldBackgroundColor;

    if (appBar != null) {
      final appBarWidget = appBar;
      final Widget sliverHeader = appBarWidget is AppBar
          ? SliverAppBar(
              floating: !pinAppBar,
              pinned: pinAppBar,
              snap: false,
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              title: appBarWidget.title,
              actions: appBarWidget.actions,
              leading: appBarWidget.leading,
              automaticallyImplyLeading:
                  appBarWidget.automaticallyImplyLeading,
              bottom: appBarWidget.bottom,
              centerTitle: appBarWidget.centerTitle,
              titleSpacing: appBarWidget.titleSpacing,
              titleTextStyle: appBarWidget.titleTextStyle,
            )
          : SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: appBarWidget!,
              ),
            );

      return Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        drawer: drawer,
        backgroundColor: effectiveBg,
        floatingActionButton: fab,
        bottomNavigationBar: bottomNavigationBar,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            sliverHeader,
          ],
          body: content,
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      drawer: drawer,
      backgroundColor: effectiveBg,
      floatingActionButton: fab,
      bottomNavigationBar: bottomNavigationBar,
      body: content,
    );
  }
}
