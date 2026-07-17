import 'package:equatable/equatable.dart';

import 'auth_user.dart';

/// Persisted auth session.
class AuthSession extends Equatable {
  const AuthSession({
    required this.user,
    required this.token,
    required this.expiresAt,
  });

  final AuthUser user;
  final String token;
  final DateTime expiresAt;

  bool get isValid => DateTime.now().isBefore(expiresAt);

  @override
  List<Object?> get props => [user, token, expiresAt];
}
