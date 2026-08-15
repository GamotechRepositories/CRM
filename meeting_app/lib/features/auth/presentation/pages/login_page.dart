import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/route_names.dart';
import '../../../../services/notification_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/loading/loading_overlay.dart';
import '../providers/auth_providers.dart';
import '../states/login_state.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  var _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    FocusScope.of(context).unfocus();
    final ok =
        await ref.read(loginControllerProvider.notifier).loginWithPassword();
    if (!mounted) return;

    final state = ref.read(loginControllerProvider);
    if (!ok) {
      context.showAppSnackBar(
        state.errorMessage ?? 'Unable to sign in',
        isError: true,
      );
      return;
    }

    await ref.read(authSessionProvider.notifier).refreshFromSession();
    if (!mounted) return;
    await NotificationService.instance.syncDeviceTokenAfterLogin();
    if (!mounted) return;
    context.go(RoutePaths.dashboard);
  }

  InputDecoration _fieldDecoration({
    required ColorScheme scheme,
    required bool isDark,
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    final fill = isDark
        ? scheme.surfaceContainerHighest
        : AppColors.surfaceContainerLight;
    final border = isDark ? scheme.outline : AppColors.borderLight;
    final muted = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(
        color: muted,
        fontWeight: FontWeight.w500,
      ),
      floatingLabelStyle: const TextStyle(
        color: Color(0xFF0F766E),
        fontWeight: FontWeight.w600,
      ),
      hintStyle: TextStyle(
        color: muted.withValues(alpha: 0.85),
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Icon(icon, size: 22, color: muted),
      suffixIcon: suffix,
      prefixIconColor: muted,
      suffixIconColor: muted,
      filled: true,
      fillColor: fill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: AppRadius.lgAll,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.lgAll,
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.lgAll,
        borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.lgAll,
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppRadius.lgAll,
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
    );
  }

  TextStyle? _fieldTextStyle(ColorScheme scheme) {
    return context.textTheme.bodyLarge?.copyWith(
      color: scheme.onSurface,
      fontWeight: FontWeight.w500,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginControllerProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final scheme = context.colorScheme;
    final isDark = context.isDarkMode;
    final pageBg =
        isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final cardBg = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final cardBorder = isDark ? AppColors.borderDark : AppColors.borderLight;
    final primaryText =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: pageBg,
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: pageBg,
        body: LoadingOverlay(
          isLoading: state.isLoading,
          message: 'Signing in…',
          child: Stack(
            children: [
              // Top-left colorful gradient orb
              Positioned(
                top: -90,
                left: -50,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF0F766E)
                            .withValues(alpha: isDark ? 0.35 : 0.2),
                        const Color(0xFF2563EB)
                            .withValues(alpha: isDark ? 0.2 : 0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Bottom-right colorful gradient orb
              Positioned(
                bottom: -60,
                right: -50,
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF7C3AED)
                            .withValues(alpha: isDark ? 0.3 : 0.15),
                        const Color(0xFF0F766E)
                            .withValues(alpha: isDark ? 0.15 : 0.05),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: CustomScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.xl + bottomInset,
                      ),
                      sliver: SliverFillRemaining(
                        hasScrollBody: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: AppSpacing.md),
                            // Brand Header
                            Column(
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF0F766E),
                                        Color(0xFF2563EB),
                                        Color(0xFF7C3AED),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF0F766E)
                                            .withValues(alpha: 0.38),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(17),
                                    child: Image.asset(
                                      AppConstants.appLogoPath,
                                      width: 66,
                                      height: 66,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(
                                        Icons.groups_rounded,
                                        color: Colors.white,
                                        size: 36,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                ShaderMask(
                                  shaderCallback: (bounds) => const LinearGradient(
                                    colors: [
                                      Color(0xFF0F766E),
                                      Color(0xFF2563EB),
                                    ],
                                  ).createShader(bounds),
                                  child: Text(
                                    AppConstants.appName,
                                    textAlign: TextAlign.center,
                                    style: context.textTheme.headlineMedium
                                        ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  AppConstants.appTagline,
                                  textAlign: TextAlign.center,
                                  style: context.textTheme.bodyMedium?.copyWith(
                                    color: secondaryText,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            )
                                .animate()
                                .fadeIn(duration: 420.ms)
                                .slideY(begin: -0.06, end: 0),
                            const SizedBox(height: AppSpacing.lg),

                            // Colorful Form Card
                            Container(
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: AppRadius.xlAll,
                                border: Border.all(color: cardBorder),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                      alpha: isDark ? 0.4 : 0.07,
                                    ),
                                    blurRadius: 24,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Top vibrant accent bar
                                  Container(
                                    height: 4,
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xFF0F766E),
                                          Color(0xFF2563EB),
                                          Color(0xFF7C3AED),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding:
                                        const EdgeInsets.all(AppSpacing.lg),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          'Welcome back',
                                          style: context.textTheme.titleLarge
                                              ?.copyWith(
                                            color: primaryText,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Sign in with your email and password.',
                                          style: context.textTheme.bodyMedium
                                              ?.copyWith(
                                            color: secondaryText,
                                            height: 1.35,
                                          ),
                                        ),
                                        const SizedBox(height: AppSpacing.lg),
                                        TextField(
                                          controller: _emailController,
                                          focusNode: _emailFocus,
                                          enabled: !state.isLoading,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          textInputAction: TextInputAction.next,
                                          style: _fieldTextStyle(scheme),
                                          cursorColor: const Color(0xFF0F766E),
                                          autofillHints: const [
                                            AutofillHints.email,
                                          ],
                                          decoration: _fieldDecoration(
                                            scheme: scheme,
                                            isDark: isDark,
                                            label: 'Email',
                                            hint: 'you@company.com',
                                            icon: Icons.email_outlined,
                                          ),
                                          onChanged: ref
                                              .read(loginControllerProvider
                                                  .notifier)
                                              .onEmailChanged,
                                          onSubmitted: (_) =>
                                              _passwordFocus.requestFocus(),
                                        ),
                                        const SizedBox(height: AppSpacing.md),
                                        TextField(
                                          controller: _passwordController,
                                          focusNode: _passwordFocus,
                                          enabled: !state.isLoading,
                                          obscureText: _obscurePassword,
                                          textInputAction: TextInputAction.done,
                                          style: _fieldTextStyle(scheme),
                                          cursorColor: const Color(0xFF0F766E),
                                          autofillHints: const [
                                            AutofillHints.password,
                                          ],
                                          decoration: _fieldDecoration(
                                            scheme: scheme,
                                            isDark: isDark,
                                            label: 'Password',
                                            hint: 'Enter your password',
                                            icon: Icons.lock_outline_rounded,
                                            suffix: IconButton(
                                              tooltip: _obscurePassword
                                                  ? 'Show password'
                                                  : 'Hide password',
                                              onPressed: () => setState(
                                                () => _obscurePassword =
                                                    !_obscurePassword,
                                              ),
                                              icon: Icon(
                                                _obscurePassword
                                                    ? Icons.visibility_outlined
                                                    : Icons
                                                        .visibility_off_outlined,
                                                color: secondaryText,
                                              ),
                                            ),
                                          ),
                                          onChanged: ref
                                              .read(loginControllerProvider
                                                  .notifier)
                                              .onPasswordChanged,
                                          onSubmitted: (_) {
                                            if (state.canSubmit) _onLogin();
                                          },
                                        ),
                                        if (state.status == LoginStatus.error &&
                                            state.errorMessage != null) ...[
                                          const SizedBox(height: AppSpacing.md),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: AppColors.error.withValues(
                                                alpha: 0.08,
                                              ),
                                              borderRadius: AppRadius.mdAll,
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.error_outline_rounded,
                                                  size: 18,
                                                  color: AppColors.error,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    state.errorMessage!,
                                                    style: context
                                                        .textTheme.bodySmall
                                                        ?.copyWith(
                                                      color: AppColors.error,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: AppSpacing.lg),

                                        // Vibrant Gradient Sign In Button
                                        Container(
                                          height: AppConstants.minTouchTarget + 4,
                                          decoration: BoxDecoration(
                                            borderRadius: AppRadius.lgAll,
                                            gradient: state.canSubmit
                                                ? const LinearGradient(
                                                    colors: [
                                                      Color(0xFF0F766E),
                                                      Color(0xFF2563EB),
                                                    ],
                                                  )
                                                : null,
                                            color: !state.canSubmit
                                                ? (isDark
                                                    ? Colors.white12
                                                    : Colors.black12)
                                                : null,
                                            boxShadow: state.canSubmit
                                                ? [
                                                    BoxShadow(
                                                      color: const Color(
                                                              0xFF0F766E)
                                                          .withValues(
                                                              alpha: 0.35),
                                                      blurRadius: 16,
                                                      offset: const Offset(0, 6),
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: state.canSubmit
                                                  ? _onLogin
                                                  : null,
                                              borderRadius: AppRadius.lgAll,
                                              child: Center(
                                                child: state.isLoading
                                                    ? const SizedBox(
                                                        width: 22,
                                                        height: 22,
                                                        child:
                                                            CircularProgressIndicator(
                                                          strokeWidth: 2.4,
                                                          color: Colors.white,
                                                        ),
                                                      )
                                                    : Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Text(
                                                            'Sign in',
                                                            style: context
                                                                .textTheme
                                                                .labelLarge
                                                                ?.copyWith(
                                                              color: Colors.white,
                                                              fontWeight:
                                                                  FontWeight.w700,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              width: 8),
                                                          const Icon(
                                                            Icons
                                                                .arrow_forward_rounded,
                                                            size: 18,
                                                            color: Colors.white,
                                                          ),
                                                        ],
                                                      ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                                .animate()
                                .fadeIn(delay: 80.ms, duration: 420.ms)
                                .slideY(begin: 0.04, end: 0),
                            const Spacer(),

                            // Bottom footer text
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.verified_user_outlined,
                                        size: 14,
                                        color: secondaryText.withValues(
                                          alpha: 0.8,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Secure Sign-in',
                                        style: context.textTheme.labelSmall
                                            ?.copyWith(
                                          color: secondaryText.withValues(
                                            alpha: 0.85,
                                          ),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Bangar Group · Enterprise Meeting Management',
                                    textAlign: TextAlign.center,
                                    style: context.textTheme.labelSmall
                                        ?.copyWith(
                                      color: secondaryText.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ).animate().fadeIn(delay: 180.ms),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
