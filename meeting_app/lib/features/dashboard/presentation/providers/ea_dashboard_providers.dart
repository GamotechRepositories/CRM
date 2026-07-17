import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/rbac/app_permission.dart';
import '../../../../core/rbac/rbac_providers.dart';
import '../../../meetings/presentation/providers/meeting_providers.dart';
import '../controllers/ea_dashboard_controller.dart';
import '../states/ea_dashboard_state.dart';

/// Team member = can create meetings for Boss.
final canViewEaDashboardProvider = Provider<bool>((ref) {
  final permissions = ref.watch(permissionSetProvider);
  return permissions.can(AppPermission.viewDashboard) &&
      permissions.can(AppPermission.createMeeting);
});

/// Legacy EA dashboard provider (unused by simplified UI).
final eaDashboardProvider =
    StateNotifierProvider<EaDashboardController, EaDashboardState>((ref) {
      final controller = EaDashboardController(
        meetingRepository: ref.watch(meetingRepositoryProvider),
        permissions: ref.watch(permissionSetProvider),
      );
      controller.load(null);
      return controller;
    });
