import 'package:flutter/material.dart';

import 'flipkart_bottom_nav.dart';

/// Content padding so lists clear the floating pill bar.
abstract final class ShellBottomInsets {
  static double of(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    return bottomSafe +
        FlipkartBottomNav.barHeight +
        FlipkartBottomNav.bottomGap +
        12;
  }

  static EdgeInsets paddingOf(
    BuildContext context, {
    double left = 0,
    double top = 0,
    double right = 0,
  }) {
    return EdgeInsets.fromLTRB(left, top, right, of(context));
  }
}
