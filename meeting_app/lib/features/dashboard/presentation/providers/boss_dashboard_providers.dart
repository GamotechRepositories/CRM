import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/rbac/app_permission.dart';
import '../../../../core/rbac/rbac_providers.dart';
import '../../../meetings/presentation/providers/meeting_providers.dart';
import '../controllers/boss_dashboard_controller.dart';
import '../states/boss_dashboard_state.dart';

/// Boss = view-only (cannot create meetings).
final canViewBossDashboardProvider = Provider<bool>((ref) {
  final permissions = ref.watch(permissionSetProvider);
  return permissions.can(AppPermission.viewDashboard) &&
      !permissions.canCreateMeeting;
});

/// Kept for legacy BossDashboardView; prefer SimpleMeetingDashboard.
final bossDashboardProvider =
    StateNotifierProvider<BossDashboardController, BossDashboardState>((ref) {
      final controller = BossDashboardController(
        meetingRepository: ref.watch(meetingRepositoryProvider),
        permissions: ref.watch(permissionSetProvider),
      );
      controller.load(const []);
      return controller;
    });
