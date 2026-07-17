import 'dart:convert';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/storage/hive_service.dart';
import '../models/auth_session_model.dart';

/// Local persistence for auth session.
class AuthLocalDataSource {
  AuthLocalDataSource(this._hive);

  final HiveService _hive;

  Future<AuthSessionModel?> readSession() async {
    try {
      final raw = _hive.get<String>(StorageKeys.authSession);
      if (raw == null || raw.isEmpty) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return AuthSessionModel.fromJson(json);
    } catch (_) {
      throw const CacheException('Failed to read auth session');
    }
  }

  Future<void> saveSession(AuthSessionModel session) async {
    try {
      await _hive.put(StorageKeys.authSession, jsonEncode(session.toJson()));
      await _hive.put(StorageKeys.authToken, session.token);
      await _hive.put(StorageKeys.isLoggedIn, true);
    } catch (_) {
      throw const CacheException('Failed to save auth session');
    }
  }

  Future<void> clearSession() async {
    try {
      await _hive.delete(StorageKeys.authSession);
      await _hive.delete(StorageKeys.authToken);
      await _hive.put(StorageKeys.isLoggedIn, false);
    } catch (_) {
      throw const CacheException('Failed to clear auth session');
    }
  }

  bool get isLoggedInFlag => _hive.get<bool>(StorageKeys.isLoggedIn) ?? false;
}
