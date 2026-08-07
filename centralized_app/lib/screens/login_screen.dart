import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_session.dart';
import '../config/app_env.dart';
import '../config/company_config.dart';
import 'home_screen.dart';

/// Compact employee login — company first, then email/password against that tenant.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _remember = true;
  bool _obscure = true;
  CompanyConfig? _company;

  static const _labelStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155));
  static const _hintStyle = TextStyle(fontSize: 12, color: Color(0xFF94A3B8));
  static const _inputStyle = TextStyle(fontSize: 12, color: Color(0xFF0F172A), height: 1.2);

  @override
  void initState() {
    super.initState();
    final session = context.read<AuthSession>();
    _company = session.company ?? CompanyConfig.all.first;
    session.selectCompany(_company);
    session.loadRememberedEmail().then((email) {
      if (email != null && email.isNotEmpty && mounted) {
        setState(() => _emailCtrl.text = email);
      }
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final session = context.read<AuthSession>();
    session.selectCompany(_company);
    await session.login(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      rememberEmail: _remember,
    );
    if (!mounted) return;
    if (session.isLoggedIn) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  InputDecoration _decoration(String hint, {Widget? suffix}) {
    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: _hintStyle,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.2),
      ),
      suffixIcon: suffix,
      suffixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthSession>();
    final error = session.error;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0F0F172A),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      AppEnv.appName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Employee login',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 14),

                    const Text('Company', style: _labelStyle),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<CompanyConfig>(
                      key: ValueKey(_company?.key ?? 'company'),
                      initialValue: _company,
                      isExpanded: true,
                      style: _inputStyle,
                      decoration: _decoration('Select company'),
                      items: CompanyConfig.all
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(
                                '${c.displayName} (${c.shortName})',
                                style: _inputStyle,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: session.loading
                          ? null
                          : (value) {
                              setState(() => _company = value);
                              session.selectCompany(value);
                            },
                    ),
                    if (_company != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _company!.apiBaseUrl,
                        style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 10),

                    const Text('Email', style: _labelStyle),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _emailCtrl,
                      style: _inputStyle,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      enabled: !session.loading,
                      decoration: _decoration('work@company.com'),
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 10),

                    const Text('Password', style: _labelStyle),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _passwordCtrl,
                      style: _inputStyle,
                      obscureText: _obscure,
                      enabled: !session.loading,
                      decoration: _decoration(
                        '••••••••',
                        suffix: IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          iconSize: 16,
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 16,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 6),

                    Row(
                      children: [
                        SizedBox(
                          height: 18,
                          width: 18,
                          child: Checkbox(
                            value: _remember,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            onChanged: session.loading
                                ? null
                                : (v) => setState(() => _remember = v ?? false),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Remember email',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),

                    if (error != null && error.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Text(
                          error,
                          style: const TextStyle(fontSize: 11, color: Color(0xFFB91C1C)),
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),
                    SizedBox(
                      height: 34,
                      child: FilledButton(
                        onPressed: session.loading ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: session.loading
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Sign in'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
