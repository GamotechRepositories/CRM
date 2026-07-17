import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/rbac/rbac_providers.dart';
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

final bossProfileProvider = FutureProvider<({String id, String name})>((
  ref,
) async {
  return ref.watch(meetingRemoteDataSourceProvider).getBoss();
});
