import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../services/meeting_realtime_service.dart';
import '../../../../services/notification_service.dart';
import '../../domain/repositories/auth_repository.dart';
import '../states/auth_session_state.dart';

class AuthSessionController extends StateNotifier<AuthSessionState> {
  AuthSessionController(this._repository) : super(const AuthSessionState());

  final AuthRepository _repository;

  Future<void> bootstrap() async {
    final result = await _repository.getSession();
    state = switch (result) {
      Success(:final data) when data != null && data.isValid =>
        AuthSessionState(
          status: AuthSessionStatus.authenticated,
          session: data,
        ),
      _ => const AuthSessionState(status: AuthSessionStatus.unauthenticated),
    };
  }

  Future<void> refreshFromSession() => bootstrap();

  Future<void> logout() async {
    await _repository.logout();
    await NotificationService.instance.onLogout();
    MeetingRealtimeService.instance.disconnect();
    state = const AuthSessionState(status: AuthSessionStatus.unauthenticated);
  }
}
