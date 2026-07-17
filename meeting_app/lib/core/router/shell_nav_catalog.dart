import 'package:flutter/material.dart';

import '../rbac/app_permission.dart';
import 'route_names.dart';

/// Shell destinations keyed by permission (not role names).
class ShellDestinationSpec {
  const ShellDestinationSpec({
    required this.branchIndex,
    required this.permission,
    required this.location,
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.showBadge = false,
  });

  final int branchIndex;
  final AppPermission permission;
  final String location;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool showBadge;
}

abstract final class ShellNavCatalog {
  /// Employee / team shell: Home · Meetings · Account only.
  static const destinations = <ShellDestinationSpec>[
    ShellDestinationSpec(
      branchIndex: 0,
      permission: AppPermission.viewDashboard,
      location: RoutePaths.dashboard,
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    ShellDestinationSpec(
      branchIndex: 1,
      permission: AppPermission.viewMeetingsNav,
      location: RoutePaths.meetings,
      label: 'Meetings',
      icon: Icons.calendar_month_outlined,
      activeIcon: Icons.calendar_month_rounded,
      showBadge: true,
    ),
    ShellDestinationSpec(
      branchIndex: 2,
      permission: AppPermission.viewSettings,
      location: RoutePaths.settings,
      label: 'Account',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
    ),
  ];

  static List<ShellDestinationSpec> visibleFor(
    bool Function(AppPermission) can,
  ) {
    return destinations.where((d) => can(d.permission)).toList();
  }

  static String homeLocation(bool Function(AppPermission) can) {
    final visible = visibleFor(can);
    if (visible.isEmpty) return RoutePaths.settings;
    return visible.first.location;
  }
}
