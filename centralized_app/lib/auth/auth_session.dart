import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_cache.dart';
import '../api/company_api.dart';
import '../config/company_config.dart';
import '../services/work_reminder_service.dart';
import '../utils/attendance_helpers.dart';
import 'role_access.dart';

const _kCompanyKey = 'crm_selected_company';
const _kUserKey = 'crm_user';
const _kRememberEmail = 'crm_remember_email';
const _kSessionDateKey = 'crm_session_date';

class AuthSession extends ChangeNotifier {
  CompanyConfig? _company;
  Map<String, dynamic>? _user;
  bool _ready = false;
  bool _loading = false;
  String? _error;
  bool _sessionExpiredNotice = false;
  bool _showCheckInPrompt = false;

  CompanyConfig? get company => _company;
  Map<String, dynamic>? get user => _user;
  bool get isLoggedIn => _user != null && _company != null;
  bool get ready => _ready;
  bool get loading => _loading;
  String? get error => _error;
  bool get sessionExpiredNotice => _sessionExpiredNotice;
  bool get showCheckInPrompt => _showCheckInPrompt;

  String get userName => (_user?['name'] ?? '').toString();
  String get userEmail => (_user?['email'] ?? '').toString();
  String get userId => (_user?['_id'] ?? _user?['id'] ?? '').toString();
  bool get canViewAdminDashboard => RoleAccess.canViewAdminDashboard(_user);

  CompanyApi? get api =>
      _company == null ? null : CompanyApi(_company!);

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _company = CompanyConfig.byKey(prefs.getString(_kCompanyKey));
    final sessionDate = prefs.getString(_kSessionDateKey);
    final today = AttendanceHelpers.todayKey();
    final raw = prefs.getString(_kUserKey);

    if (raw != null && raw.isNotEmpty && sessionDate == today) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) _user = decoded;
      } catch (_) {
        _user = null;
      }
    } else if (raw != null && raw.isNotEmpty) {
      // Prior day's session: invalidate to enforce daily login
      _user = null;
      _sessionExpiredNotice = true;
      await prefs.remove(_kUserKey);
      await prefs.remove(_kSessionDateKey);
    }
    _ready = true;
    notifyListeners();
  }

  void selectCompany(CompanyConfig? company) {
    if (_company?.key == company?.key && _error == null) return;
    _company = company;
    _error = null;
    notifyListeners();
  }

  Future<String?> loadRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kRememberEmail);
  }

  void consumeCheckInPrompt() {
    if (_showCheckInPrompt) {
      _showCheckInPrompt = false;
      notifyListeners();
    }
  }

  void consumeSessionExpiredNotice() {
    if (_sessionExpiredNotice) {
      _sessionExpiredNotice = false;
      notifyListeners();
    }
  }

  Future<void> checkDailySession() async {
    if (!isLoggedIn) return;
    final prefs = await SharedPreferences.getInstance();
    final sessionDate = prefs.getString(_kSessionDateKey);
    final today = AttendanceHelpers.todayKey();
    if (sessionDate != null && sessionDate != today) {
      await logout(dayChangeExpired: true);
    }
  }

  Future<void> login({
    required String email,
    required String password,
    required bool rememberEmail,
  }) async {
    if (_company == null) {
      _error = 'Select a company first';
      notifyListeners();
      return;
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await CompanyApi(_company!).login(
        email: email,
        password: password,
      );
      final user = res['user'];
      if (user is! Map) {
        throw Exception(res['message']?.toString() ?? 'Login failed');
      }
      _user = Map<String, dynamic>.from(user);
      final today = AttendanceHelpers.todayKey();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCompanyKey, _company!.key);
      await prefs.setString(_kUserKey, jsonEncode(_user));
      await prefs.setString(_kSessionDateKey, today);
      _showCheckInPrompt = true;
      _sessionExpiredNotice = false;
      if (rememberEmail) {
        await prefs.setString(_kRememberEmail, email.trim());
      } else {
        await prefs.remove(_kRememberEmail);
      }
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _user = null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> logout({bool dayChangeExpired = false}) async {
    _user = null;
    _showCheckInPrompt = false;
    if (dayChangeExpired) {
      _sessionExpiredNotice = true;
    }
    ApiCache.clear();
    await WorkReminderService.instance.stop();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserKey);
    await prefs.remove(_kSessionDateKey);
    // Keep last company selection for convenience.
    notifyListeners();
  }
}
