import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/company_api.dart';
import '../config/company_config.dart';
import 'role_access.dart';

const _kCompanyKey = 'crm_selected_company';
const _kUserKey = 'crm_user';
const _kRememberEmail = 'crm_remember_email';

class AuthSession extends ChangeNotifier {
  CompanyConfig? _company;
  Map<String, dynamic>? _user;
  bool _ready = false;
  bool _loading = false;
  String? _error;

  CompanyConfig? get company => _company;
  Map<String, dynamic>? get user => _user;
  bool get isLoggedIn => _user != null && _company != null;
  bool get ready => _ready;
  bool get loading => _loading;
  String? get error => _error;

  String get userName => (_user?['name'] ?? '').toString();
  String get userEmail => (_user?['email'] ?? '').toString();
  String get userId => (_user?['_id'] ?? _user?['id'] ?? '').toString();
  bool get canViewAdminDashboard => RoleAccess.canViewAdminDashboard(_user);

  CompanyApi? get api =>
      _company == null ? null : CompanyApi(_company!);

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _company = CompanyConfig.byKey(prefs.getString(_kCompanyKey));
    final raw = prefs.getString(_kUserKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) _user = decoded;
      } catch (_) {
        _user = null;
      }
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCompanyKey, _company!.key);
      await prefs.setString(_kUserKey, jsonEncode(_user));
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

  Future<void> logout() async {
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserKey);
    // Keep last company selection for convenience.
    notifyListeners();
  }
}
