import 'package:flutter/material.dart';

import 'breakpoints.dart';

enum DeviceType { mobile, tablet, desktop, wide }

class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
    this.wide,
  });

  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;
  final Widget? wide;

  static DeviceType deviceTypeOf(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= Breakpoints.wide) return DeviceType.wide;
    if (width >= Breakpoints.desktop) return DeviceType.desktop;
    if (width >= Breakpoints.tablet) return DeviceType.tablet;
    return DeviceType.mobile;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        if (width >= Breakpoints.wide && wide != null) return wide!;
        if (width >= Breakpoints.desktop && desktop != null) return desktop!;
        if (width >= Breakpoints.tablet && tablet != null) return tablet!;
        return mobile;
      },
    );
  }
}

/// Constrains content width on large screens for readability.
class ResponsiveContainer extends StatelessWidget {
  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.desktop,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
