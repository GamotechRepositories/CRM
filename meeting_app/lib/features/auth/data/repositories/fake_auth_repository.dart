import 'package:flutter/foundation.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../organization/domain/organization_constants.dart';
import '../../../organization/domain/repositories/organization_repository.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../models/auth_session_model.dart';

/// Fake auth repository — resolves Boss vs company-scoped members from demo org.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository(this._local, this._organization);

  final AuthLocalDataSource _local;
  final OrganizationRepository _organization;

  static const _delay = Duration(seconds: 2);
  static const validOtp = OrganizationConstants.demoOtp;

  @override
  Future<Result<AuthSession?>> getSession() async {
    try {
      final model = await _local.readSession();
      if (model == null) return const Success(null);
      final session = model.toEntity();
      if (!session.isValid) {
        await _local.clearSession();
        return const Success(null);
      }
      return Success(session);
    } catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'FakeAuth.getSession');
      return Error(ErrorHandler.mapException(error));
    }
  }

  @override
  Future<Result<bool>> isLoggedIn() async {
    final sessionResult = await getSession();
    return switch (sessionResult) {
      Success(:final data) => Success(data != null && data.isValid),
      Error(:final failure) => Error(failure),
    };
  }

  @override
  Future<Result<AuthSession>> loginWithPassword({
    required String email,
    required String password,
  }) async {
    return const Error(
      ValidationFailure('Demo auth uses OTP. Switch to remote backend login.'),
    );
  }

  @override
  Future<Result<String>> sendOtp(String mobileNumber) async {
    await Future<void>.delayed(_delay);
    try {
      final digits = mobileNumber.replaceAll(RegExp(r'\D'), '');
      if (digits.length != 10) {
        return const Error(
          ValidationFailure('Enter a valid 10-digit mobile number'),
        );
      }
      final requestId =
          'req_${digits}_${DateTime.now().millisecondsSinceEpoch}';
      if (kDebugMode) {
        debugPrint('[FakeAuth] OTP sent to $digits — use $validOtp');
      }
      return Success(requestId);
    } catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'FakeAuth.sendOtp');
      return Error(ErrorHandler.mapException(error));
    }
  }

  @override
  Future<Result<AuthSession>> verifyOtp({
    required String mobileNumber,
    required String otp,
    required String requestId,
  }) async {
    await Future<void>.delayed(_delay);
    try {
      if (otp != validOtp) {
        return const Error(ValidationFailure('Invalid OTP. Please try again.'));
      }

      final digits = mobileNumber.replaceAll(RegExp(r'\D'), '');
      final user = await _resolveUser(digits);

      final session = AuthSessionModel(
        user: AuthUserModel.fromEntity(user),
        token: 'fake_token_${DateTime.now().millisecondsSinceEpoch}',
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );

      await _local.saveSession(session);

      // Boss lands on first owned company; members lock to home company.
      if (user.isBoss) {
        final companies = await _organization.getAccessibleCompanies(user);
        if (companies case Success(:final data) when data.isNotEmpty) {
          final active = await _organization.getActiveCompanyId();
          final stillValid = data.any((c) => c.id == active);
          if (active == null || !stillValid) {
            await _organization.setActiveCompanyId(data.first.id);
          }
        }
      } else if (user.homeCompanyId != null) {
        await _organization.setActiveCompanyId(user.homeCompanyId!);
      }

      return Success(session.toEntity());
    } catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'FakeAuth.verifyOtp');
      return Error(ErrorHandler.mapException(error));
    }
  }

  Future<AuthUser> _resolveUser(String digits) async {
    if (digits == OrganizationConstants.bossMobile) {
      return const AuthUser(
        id: OrganizationConstants.bossId,
        mobileNumber: OrganizationConstants.bossMobile,
        displayName: OrganizationConstants.bossName,
        appRole: AppRole.boss,
      );
    }

    final lookup = await _organization.findMemberByMobile(digits);
    if (lookup case Success(:final data) when data != null) {
      final employee = data.employee;
      return AuthUser(
        // Use the employee ID as the canonical actor ID. Meeting ownership,
        // team scope, and participant invitations all reference this ID.
        id: employee.id,
        mobileNumber: employee.mobile,
        displayName: employee.name,
        appRole: AppRole.member,
        employeeId: employee.id,
        employeeRole: employee.role,
        homeCompanyId: employee.companyId,
      );
    }

    // Unknown mobile — treat as provisional boss-less guest (no companies).
    return AuthUser(
      id: 'user_$digits',
      mobileNumber: digits,
      displayName: 'Guest User',
      appRole: AppRole.member,
    );
  }

  @override
  Future<Result<void>> resendOtp({
    required String mobileNumber,
    required String requestId,
  }) async {
    await Future<void>.delayed(_delay);
    if (kDebugMode) {
      debugPrint('[FakeAuth] OTP resent — use $validOtp');
    }
    return const Success(null);
  }

  @override
  Future<Result<void>> logout() async {
    try {
      await _local.clearSession();
      return const Success(null);
    } catch (error, stack) {
      ErrorHandler.logError(error, stack, context: 'FakeAuth.logout');
      return Error(ErrorHandler.mapException(error));
    }
  }
}
