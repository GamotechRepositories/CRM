import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';

/// 6-digit OTP input with auto-focus and paste support.
class OtpInputField extends StatefulWidget {
  const OtpInputField({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.hasError = false,
    this.length = 6,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final bool hasError;
  final int length;

  @override
  State<OtpInputField> createState() => _OtpInputFieldState();
}

class _OtpInputFieldState extends State<OtpInputField> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _nodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _nodes = List.generate(widget.length, (_) => FocusNode());
    _syncFromValue(widget.value);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.enabled) _nodes.first.requestFocus();
    });
  }

  @override
  void didUpdateWidget(covariant OtpInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _syncFromValue(widget.value);
      if (widget.value.isEmpty && widget.enabled) {
        _nodes.first.requestFocus();
      }
    }
  }

  void _syncFromValue(String value) {
    for (var i = 0; i < widget.length; i++) {
      final char = i < value.length ? value[i] : '';
      if (_controllers[i].text != char) {
        _controllers[i].text = char;
      }
    }
  }

  void _emit() {
    widget.onChanged(_controllers.map((c) => c.text).join());
  }

  void _onChanged(int index, String text) {
    if (text.length > 1) {
      // Paste handling
      final digits = text.replaceAll(RegExp(r'\D'), '');
      for (var i = 0; i < widget.length; i++) {
        _controllers[i].text = i < digits.length ? digits[i] : '';
      }
      final focusIndex = digits.length >= widget.length
          ? widget.length - 1
          : digits.length;
      _nodes[focusIndex.clamp(0, widget.length - 1)].requestFocus();
      _emit();
      return;
    }

    if (text.isNotEmpty && index < widget.length - 1) {
      _nodes[index + 1].requestFocus();
    }
    _emit();
  }

  void _onKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _nodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
      _emit();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final row = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(widget.length, (index) {
        return SizedBox(
          width: 48,
          height: 56,
          child: KeyboardListener(
            focusNode: FocusNode(skipTraversal: true),
            onKeyEvent: (event) => _onKey(index, event),
            child: TextField(
              controller: _controllers[index],
              focusNode: _nodes[index],
              enabled: widget.enabled,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: 1,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(borderRadius: AppRadius.mdAll),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.mdAll,
                  borderSide: BorderSide(
                    color: widget.hasError
                        ? scheme.error
                        : scheme.outline.withValues(alpha: 0.45),
                    width: widget.hasError ? 1.5 : 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.mdAll,
                  borderSide: BorderSide(
                    color: widget.hasError ? scheme.error : scheme.primary,
                    width: 2,
                  ),
                ),
              ),
              onChanged: (v) => _onChanged(index, v),
            ),
          ),
        );
      }),
    );

    if (widget.hasError) {
      return row
          .animate(key: ValueKey('otp_error_${widget.value}'))
          .shake(hz: 4, duration: 400.ms, curve: Curves.easeInOut);
    }
    return row;
  }
}

class ResendOtpButton extends StatelessWidget {
  const ResendOtpButton({
    super.key,
    required this.secondsRemaining,
    required this.onResend,
    this.isLoading = false,
  });

  final int secondsRemaining;
  final VoidCallback onResend;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final canResend = secondsRemaining <= 0 && !isLoading;
    final scheme = Theme.of(context).colorScheme;

    if (!canResend) {
      return Text(
        'Resend OTP in ${secondsRemaining}s',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      );
    }

    return TextButton(
      onPressed: isLoading ? null : onResend,
      child: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('Resend OTP'),
    );
  }
}

class OtpSuccessOverlay extends StatelessWidget {
  const OtpSuccessOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: scheme.scrim.withValues(alpha: 0.45),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 56,
                    color: scheme.onPrimaryContainer,
                  ),
                )
                .animate()
                .scale(
                  begin: const Offset(0.4, 0.4),
                  end: const Offset(1, 1),
                  duration: 450.ms,
                  curve: Curves.elasticOut,
                )
                .fadeIn(),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Verified successfully',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.2, end: 0),
          ],
        ),
      ),
    );
  }
}
