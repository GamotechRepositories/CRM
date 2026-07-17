import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/rbac/rbac_providers.dart';
import '../../../../core/router/shell_nav_catalog.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/loading/loading_overlay.dart';
import '../providers/auth_providers.dart';
import '../states/otp_state.dart';
import '../widgets/auth_gradient_background.dart';
import '../widgets/auth_hero_logo.dart';
import '../widgets/auth_welcome_illustration.dart';
import '../widgets/glass_card.dart';
import '../widgets/mobile_number_field.dart';
import '../widgets/otp_input_field.dart';

class OtpPage extends ConsumerStatefulWidget {
  const OtpPage({
    super.key,
    required this.mobileNumber,
    required this.requestId,
  });

  final String mobileNumber;
  final String requestId;

  @override
  ConsumerState<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends ConsumerState<OtpPage> {
  late final OtpArgs _args;

  @override
  void initState() {
    super.initState();
    _args = OtpArgs(
      mobileNumber: widget.mobileNumber,
      requestId: widget.requestId,
    );
  }

  Future<void> _handleVerified() async {
    await ref.read(authSessionProvider.notifier).refreshFromSession();
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    context.go(
      ShellNavCatalog.homeLocation(ref.read(permissionSetProvider).can),
    );
  }

  Future<void> _onResend() async {
    final ok = await ref
        .read(otpControllerProvider(_args).notifier)
        .resendOtp();
    if (!mounted) return;
    if (ok) {
      context.showAppSnackBar('OTP resent successfully');
    } else {
      final state = ref.read(otpControllerProvider(_args));
      context.showAppSnackBar(
        state.errorMessage ?? 'Unable to resend OTP',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(otpControllerProvider(_args));
    final masked = _maskMobile(state.mobileNumber);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    ref.listen(otpControllerProvider(_args), (previous, next) {
      if (previous?.status != OtpStatus.success &&
          next.status == OtpStatus.success &&
          next.showSuccess) {
        _handleVerified();
      }
      if (previous?.status != OtpStatus.error &&
          next.status == OtpStatus.error &&
          next.errorMessage != null) {
        context.showAppSnackBar(next.errorMessage!, isError: true);
      }
    });

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: AuthGradientBackground(
        child: Stack(
          children: [
            LoadingOverlay(
              isLoading: state.status == OtpStatus.loading,
              message: 'Verifying OTP…',
              child: SafeArea(
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        tooltip: 'Back',
                        onPressed: state.isLoading ? null : () => context.pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          0,
                          AppSpacing.lg,
                          AppSpacing.lg + bottomInset,
                        ),
                        child: Column(
                          children: [
                            const AuthHeroLogo(
                              size: 64,
                              showTitle: false,
                            ).animate().fadeIn().slideY(begin: -0.08, end: 0),
                            const SizedBox(height: AppSpacing.lg),
                            GlassCard(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      AuthScreenHeader(
                                            title: 'Verify OTP',
                                            subtitle:
                                                'Enter the 6-digit code sent to +91 $masked',
                                          )
                                          .animate()
                                          .fadeIn(delay: 100.ms)
                                          .slideY(begin: 0.08, end: 0),
                                      const SizedBox(height: AppSpacing.xl),
                                      OtpInputField(
                                            value: state.otp,
                                            enabled: !state.isLoading,
                                            hasError:
                                                state.status == OtpStatus.error,
                                            onChanged: (value) {
                                              ref
                                                  .read(
                                                    otpControllerProvider(
                                                      _args,
                                                    ).notifier,
                                                  )
                                                  .onOtpChanged(value);
                                            },
                                          )
                                          .animate()
                                          .fadeIn(delay: 200.ms)
                                          .slideY(begin: 0.08, end: 0),
                                      if (state.errorMessage != null &&
                                          state.status == OtpStatus.error) ...[
                                        const SizedBox(height: AppSpacing.sm),
                                        Text(
                                          state.errorMessage!,
                                          style: context.textTheme.bodySmall
                                              ?.copyWith(
                                                color:
                                                    context.colorScheme.error,
                                              ),
                                        ).animate().fadeIn().shake(
                                          hz: 3,
                                          duration: 350.ms,
                                        ),
                                      ],
                                      const SizedBox(height: AppSpacing.lg),
                                      AuthPrimaryButton(
                                        label: 'Verify',
                                        icon: Icons.verified_outlined,
                                        isLoading:
                                            state.status == OtpStatus.loading,
                                        enabled: state.canVerify,
                                        onPressed: () {
                                          ref
                                              .read(
                                                otpControllerProvider(
                                                  _args,
                                                ).notifier,
                                              )
                                              .verifyOtp();
                                        },
                                      ).animate().fadeIn(delay: 300.ms),
                                      const SizedBox(height: AppSpacing.md),
                                      Center(
                                        child: ResendOtpButton(
                                          secondsRemaining:
                                              state.resendSecondsRemaining,
                                          isLoading:
                                              state.status ==
                                              OtpStatus.resending,
                                          onResend: _onResend,
                                        ),
                                      ),
                                      const SizedBox(height: AppSpacing.sm),
                                      Center(
                                        child: Text(
                                          'Demo OTP: $kDemoOtp',
                                          style: context.textTheme.labelSmall,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                .animate()
                                .fadeIn(delay: 120.ms)
                                .slideY(begin: 0.1, end: 0),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (state.showSuccess)
              const Positioned.fill(child: OtpSuccessOverlay()),
          ],
        ),
      ),
    );
  }

  String _maskMobile(String mobile) {
    if (mobile.length < 4) return mobile;
    return '${mobile.substring(0, 2)}******${mobile.substring(mobile.length - 2)}';
  }
}
