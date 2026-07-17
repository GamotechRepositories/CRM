import 'package:flutter/material.dart';

/// One icon-only tab for the floating Flipkart-style bottom bar.
class FlipkartNavItem {
  const FlipkartNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.showBadge = false,
    this.branchIndex,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool showBadge;

  /// go_router [StatefulShellBranch] index (may differ from visible tab index).
  final int? branchIndex;
}
