import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/rbac/rbac_providers.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/router/shell_nav_catalog.dart';
import '../../../../core/utils/logger.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/states/auth_session_state.dart';
import '../../../../services/notification_service.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      await Future.wait([
        Future<void>.delayed(AppConstants.splashDuration),
        ref.read(authSessionProvider.notifier).bootstrap(),
      ]);
    } catch (error, stack) {
      AppLogger.error(
        'Splash bootstrap failed: $error\n$stack',
      );
    }

    if (!mounted) return;

    final auth = ref.read(authSessionProvider);
    final permissions = ref.read(permissionSetProvider);
    final destination = auth.status == AuthSessionStatus.authenticated
        ? ShellNavCatalog.homeLocation(permissions.can)
        : RoutePaths.login;

    context.go(destination);

    if (auth.status == AuthSessionStatus.authenticated) {
      unawaited(_syncPushNotifications());
    }
  }

  Future<void> _syncPushNotifications() async {
    try {
      if (!NotificationService.instance.isInitialized) {
        await NotificationService.instance
            .initialize()
            .timeout(AppConstants.networkTimeout);
      }
      await NotificationService.instance
          .syncDeviceTokenAfterLogin()
          .timeout(AppConstants.networkTimeout);
      await NotificationService.instance.handleInitialMessage();
    } catch (error) {
      AppLogger.warning(
        'Push sync after splash skipped: $error',
        tag: 'FCM',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary.withValues(alpha: 0.08),
              colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: colorScheme.primary,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 300.ms),
                const SizedBox(height: 20),
                Text(
                      AppConstants.appName,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    )
                    .animate()
                    .fadeIn(delay: 150.ms, duration: 400.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
