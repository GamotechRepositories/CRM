import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/rbac/rbac_providers.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/router/shell_nav_catalog.dart';
import '../../../../shared/widgets/loading/lottie_loading.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/states/auth_session_state.dart';
import '../../../auth/presentation/widgets/auth_hero_logo.dart';

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
    await Future.wait([
      Future<void>.delayed(AppConstants.splashDuration),
      ref.read(authSessionProvider.notifier).bootstrap(),
    ]);

    if (!mounted) return;

    final auth = ref.read(authSessionProvider);
    if (auth.status == AuthSessionStatus.authenticated) {
      final permissions = ref.read(permissionSetProvider);
      context.go(ShellNavCatalog.homeLocation(permissions.can));
    } else {
      context.go(RoutePaths.login);
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
                const AuthHeroLogo(size: 96, showTitle: false),
                const SizedBox(height: 20),
                const LottieLoading(size: 100),
                const SizedBox(height: 16),
                Text(
                      AppConstants.appName,
                      style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    )
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 500.ms)
                    .slideY(begin: 0.2, end: 0),
                const SizedBox(height: 8),
                Text(
                      AppConstants.appTagline,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    )
                    .animate()
                    .fadeIn(delay: 400.ms, duration: 500.ms)
                    .slideY(begin: 0.2, end: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
