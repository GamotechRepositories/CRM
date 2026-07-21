import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/rbac/rbac_providers.dart';
import '../../../../services/meeting_realtime_service.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/states/auth_session_state.dart';
import '../../data/datasources/meeting_remote_datasource.dart';
import '../../data/repositories/remote_meeting_repository.dart';
import '../../domain/repositories/meeting_repository.dart';
import '../controllers/meetings_controller.dart';
import '../states/meetings_state.dart';

final meetingRemoteDataSourceProvider = Provider<MeetingRemoteDataSource>((
  ref,
) {
  return MeetingRemoteDataSource(ref.watch(dioProvider));
});

final meetingRepositoryProvider = Provider<MeetingRepository>((ref) {
  return RemoteMeetingRepository(ref.watch(meetingRemoteDataSourceProvider));
});

final meetingsControllerProvider =
    StateNotifierProvider<MeetingsController, MeetingsState>((ref) {
      final controller = MeetingsController(
        repository: ref.watch(meetingRepositoryProvider),
        permissions: ref.watch(permissionSetProvider),
        currentUserId: ref.watch(currentUserIdProvider),
      );
      controller.load(null);
      return controller;
    });

/// Keeps Socket.IO connected while authenticated and silently reloads meetings.
final meetingRealtimeSyncProvider = Provider<void>((ref) {
  final auth = ref.watch(authSessionProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (auth.status != AuthSessionStatus.authenticated ||
      userId == null ||
      userId.trim().isEmpty) {
    MeetingRealtimeService.instance.disconnect();
    return;
  }

  MeetingRealtimeService.instance.connect(userId: userId);

  final sub = MeetingRealtimeService.instance.changes.listen((_) {
    ref.read(meetingsControllerProvider.notifier).load(
          null,
          showLoader: false,
        );
  });

  ref.onDispose(sub.cancel);
});

final bossProfileProvider = FutureProvider<({String id, String name})>((
  ref,
) async {
  return ref.watch(meetingRemoteDataSourceProvider).getBoss();
});
