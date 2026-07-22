import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/rbac/rbac_providers.dart';
import '../../../../services/meeting_realtime_service.dart';
import '../../../../services/notification_service.dart';
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

/// Live sync for Home + Your meetings. Event-driven; never drops a refresh.
final meetingRealtimeSyncProvider = Provider<void>((ref) {
  final auth = ref.watch(authSessionProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (auth.status != AuthSessionStatus.authenticated ||
      userId == null ||
      userId.trim().isEmpty) {
    MeetingRealtimeService.instance.disconnect(resetSession: true);
    return;
  }

  MeetingRealtimeService.instance.connect(
    userId: userId,
    suppressBossTeamAlerts: ref.watch(permissionSetProvider).isBoss,
  );
  NotificationService.instance.setSuppressBossTeamAlerts(
    ref.watch(permissionSetProvider).isBoss,
  );

  Timer? debounce;
  Timer? pendingRetry;
  DateTime? lastReloadAt;
  var reloadQueued = false;

  Future<void> runReload() async {
    lastReloadAt = DateTime.now();
    await ref.read(meetingsControllerProvider.notifier).load(
          null,
          showLoader: false,
        );
    if (reloadQueued) {
      reloadQueued = false;
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 400), () {
        unawaited(runReload());
      });
    }
  }

  void requestReload() {
    final now = DateTime.now();
    final since = lastReloadAt == null
        ? const Duration(days: 1)
        : now.difference(lastReloadAt!);

    // Coalesce bursts, but never drop the last event.
    if (since < const Duration(seconds: 2)) {
      reloadQueued = true;
      pendingRetry?.cancel();
      final wait = const Duration(seconds: 2) - since + const Duration(milliseconds: 50);
      pendingRetry = Timer(wait, () {
        if (!reloadQueued) return;
        reloadQueued = false;
        unawaited(runReload());
      });
      return;
    }

    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(runReload());
    });
  }

  final socketSub = MeetingRealtimeService.instance.changes.listen((event) {
    final source = event['source']?.toString() ?? 'socket';
    if (source == 'socket-connect') return;
    requestReload();
  });

  // FCM is reliable on mobile even when Socket.IO "looks" connected but
  // misses broadcasts (common on Render). Always refresh — coalesced above.
  final previousFcm = NotificationService.instance.onMeetingSignal;
  NotificationService.instance.onMeetingSignal = (meetingId) {
    previousFcm?.call(meetingId);
    MeetingRealtimeService.instance.notifyChanged(
      meetingId: meetingId,
      source: 'fcm',
    );
  };

  final lifecycle = _MeetingLifecycleReloader(
    onResume: () {
      final stale = lastReloadAt == null ||
          DateTime.now().difference(lastReloadAt!) >
              const Duration(seconds: 45);
      if (!MeetingRealtimeService.instance.isConnected || stale) {
        MeetingRealtimeService.instance.notifyChanged(source: 'app-resume');
      }
    },
  );
  WidgetsBinding.instance.addObserver(lifecycle);

  ref.onDispose(() {
    debounce?.cancel();
    pendingRetry?.cancel();
    socketSub.cancel();
    WidgetsBinding.instance.removeObserver(lifecycle);
    if (NotificationService.instance.onMeetingSignal != previousFcm) {
      NotificationService.instance.onMeetingSignal = previousFcm;
    }
  });
});

class _MeetingLifecycleReloader with WidgetsBindingObserver {
  _MeetingLifecycleReloader({required this.onResume});

  final VoidCallback onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResume();
    }
  }
}

final bossProfileProvider = FutureProvider<({String id, String name})>((
  ref,
) async {
  return ref.watch(meetingRemoteDataSourceProvider).getBoss();
});
