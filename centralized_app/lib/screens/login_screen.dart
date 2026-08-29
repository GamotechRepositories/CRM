import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_session.dart';
import '../config/app_env.dart';
import '../config/company_config.dart';
import 'app_home.dart';

/// Employee login — company first, then email/password against that tenant.
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

  static const _primaryBlue = Color(0xFF1E88E5);
  static const _primaryBlueDark = Color(0xFF1565C0);
  static const _labelStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155));
  static const _hintStyle = TextStyle(fontSize: 13, color: Color(0xFF94A3B8));
  static const _inputStyle = TextStyle(fontSize: 13, color: Color(0xFF0F172A), height: 1.2);

  @override
  void initState() {
    super.initState();
    final session = context.read<AuthSession>();
    _company = session.company ?? CompanyConfig.all.first;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthSession>().selectCompany(_company);
    });
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
        MaterialPageRoute(builder: (_) => const AppHome()),
      );
    }
  }

  void _forgotPassword() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please contact your administrator to reset your password.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  InputDecoration _decoration(String hint, {Widget? prefix, Widget? suffix}) {
    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: _hintStyle,
      prefixIcon: prefix,
      prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
      ),
      suffixIcon: suffix,
      suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthSession>();
    final error = session.error;

    return Scaffold(
      body: Stack(
        children: [
          const _LoginBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    children: [
                      _AppLogo(company: _company),
                      const SizedBox(height: 16),
                      _BrandTitle(appName: AppEnv.appName),
                      if (_company != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _company!.displayName,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _company!.tagline,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1A1E88E5),
                              blurRadius: 24,
                              offset: Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Color(0x0D000000),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('Select Organization', style: _labelStyle),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<CompanyConfig>(
                              key: ValueKey(_company?.key ?? 'company'),
                              initialValue: _company,
                              isExpanded: true,
                              style: _inputStyle,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF94A3B8)),
                              decoration: _decoration(
                                'Select company',
                                prefix: const Padding(
                                  padding: EdgeInsets.only(left: 12, right: 4),
                                  child: Icon(Icons.business_rounded, size: 20, color: _primaryBlue),
                                ),
                              ),
                              items: CompanyConfig.all
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Row(
                                        children: [
                                          CompanyLogoWidget(company: c, size: 24),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              c.displayName,
                                              style: _inputStyle,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: c.primaryColor.withAlpha(30),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              c.shortName,
                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: c.primaryColor),
                                            ),
                                          ),
                                        ],
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
                            const SizedBox(height: 16),

                            const Text('Email', style: _labelStyle),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _emailCtrl,
                              style: _inputStyle,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              enabled: !session.loading,
                              decoration: _decoration(
                                'work@company.com',
                                prefix: const Padding(
                                  padding: EdgeInsets.only(left: 12, right: 4),
                                  child: Icon(Icons.mail_outline_rounded, size: 20, color: _primaryBlue),
                                ),
                              ),
                              onSubmitted: (_) => _submit(),
                            ),
                            const SizedBox(height: 16),

                            const Text('Password', style: _labelStyle),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _passwordCtrl,
                              style: _inputStyle,
                              obscureText: _obscure,
                              enabled: !session.loading,
                              decoration: _decoration(
                                '••••••••',
                                prefix: const Padding(
                                  padding: EdgeInsets.only(left: 12, right: 4),
                                  child: Icon(Icons.lock_outline_rounded, size: 20, color: _primaryBlue),
                                ),
                                suffix: IconButton(
                                  onPressed: () => setState(() => _obscure = !_obscure),
                                  icon: Icon(
                                    _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                    size: 20,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                              ),
                              onSubmitted: (_) => _submit(),
                            ),
                            const SizedBox(height: 12),

                            Row(
                              children: [
                                SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: Checkbox(
                                    value: _remember,
                                    activeColor: _primaryBlue,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                                    onChanged: session.loading
                                        ? null
                                        : (v) => setState(() => _remember = v ?? false),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Remember email',
                                    style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                                  ),
                                ),
                                TextButton(
                                  onPressed: session.loading ? null : _forgotPassword,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Forgot password?',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _primaryBlue),
                                  ),
                                ),
                              ],
                            ),

                            if (error != null && error.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFFECACA)),
                                ),
                                child: Text(
                                  error,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
                                ),
                              ),
                            ],

                            const SizedBox(height: 16),
                            SizedBox(
                              height: 48,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  gradient: const LinearGradient(
                                    colors: [_primaryBlue, _primaryBlueDark],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x401E88E5),
                                      blurRadius: 12,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: session.loading ? null : _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: session.loading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Sign in',
                                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                            ),
                                            SizedBox(width: 6),
                                            Icon(Icons.arrow_forward_rounded, size: 18),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const _HelpFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginBackground extends StatelessWidget {
  const _LoginBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE3F2FD), Color(0xFFF8FBFF), Color(0xFFFFFFFF)],
          stops: [0.0, 0.45, 1.0],
        ),
      ),
      child: CustomPaint(
        painter: _LoginBackgroundPainter(),
        size: Size.infinite,
      ),
    );
  }
}

class _LoginBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()..color = const Color(0x331E88E5);
    const dotSpacing = 14.0;
    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 4; col++) {
        canvas.drawCircle(Offset(28 + col * dotSpacing, 48 + row * dotSpacing), 2.2, dotPaint);
      }
    }

    final arcPaint = Paint()
      ..color = const Color(0x1A1E88E5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 28;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(size.width + 20, -30), radius: 120),
      0.4,
      1.2,
      false,
      arcPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(size.width - 40, size.height + 40), radius: 90),
      3.4,
      1.0,
      false,
      arcPaint..strokeWidth = 22,
    );

    final fillPaint = Paint()..color = const Color(0x0D1E88E5);
    canvas.drawCircle(Offset(size.width - 60, 80), 50, fillPaint);
    canvas.drawCircle(Offset(40, size.height - 100), 36, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AppLogo extends StatelessWidget {
  final CompanyConfig? company;
  const _AppLogo({Key? key, this.company}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/app_logo.png',
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) {
          if (company != null) {
            return CompanyLogoWidget(company: company!, size: 88);
          }
          return const ColoredBox(
            color: Colors.black,
            child: Icon(Icons.business_rounded, color: Colors.white, size: 40),
          );
        },
      ),
    );
  }
}

class _BrandTitle extends StatelessWidget {
  const _BrandTitle({required this.appName});

  final String appName;

  @override
  Widget build(BuildContext context) {
    final name = appName.trim();

    return Column(
      children: [
        Text(
          name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: Container(height: 1, color: const Color(0xFFBBDEFB))),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Employee login',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
            ),
            Expanded(child: Container(height: 1, color: const Color(0xFFBBDEFB))),
          ],
        ),
      ],
    );
  }
}

class _HelpFooter extends StatelessWidget {
  const _HelpFooter();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.headset_mic_outlined, size: 16, color: Color(0xFF1E88E5)),
            ),
            const SizedBox(width: 8),
            const Text(
              'Need help?',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Contact your administrator',
          style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
        ),
      ],
    );
  }
}
