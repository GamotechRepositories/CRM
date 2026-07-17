import 'package:equatable/equatable.dart';

import '../../domain/entities/auth_session.dart';

enum AuthSessionStatus { unknown, authenticated, unauthenticated }

class AuthSessionState extends Equatable {
  const AuthSessionState({
    this.status = AuthSessionStatus.unknown,
    this.session,
  });

  final AuthSessionStatus status;
  final AuthSession? session;

  bool get isAuthenticated => status == AuthSessionStatus.authenticated;

  AuthSessionState copyWith({
    AuthSessionStatus? status,
    AuthSession? session,
    bool clearSession = false,
  }) {
    return AuthSessionState(
      status: status ?? this.status,
      session: clearSession ? null : (session ?? this.session),
    );
  }

  @override
  List<Object?> get props => [status, session];
}
