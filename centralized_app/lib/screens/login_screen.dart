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
                      _BrandTitle(appName: _company?.displayName ?? AppEnv.appName),
                      if (_company != null) ...[
                        const SizedBox(height: 4),
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
                            if (_company != null) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.link_rounded, size: 12, color: _primaryBlue),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      _company!.apiBaseUrl,
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
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
    if (company != null) {
      return CompanyLogoWidget(company: company!, size: 72);
    }
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x401E88E5),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _LogoIconPainter(),
        size: Size(72, 72),
      ),
    );
  }
}

class _LogoIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final fill = Paint()..color = Colors.white;

    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.28), 5, fill);
    canvas.drawCircle(Offset(size.width * 0.28, size.height * 0.62), 4.5, fill);
    canvas.drawCircle(Offset(size.width * 0.72, size.height * 0.62), 4.5, fill);

    canvas.drawLine(Offset(size.width * 0.5, size.height * 0.33), Offset(size.width * 0.32, size.height * 0.57), stroke);
    canvas.drawLine(Offset(size.width * 0.5, size.height * 0.33), Offset(size.width * 0.68, size.height * 0.57), stroke);
    canvas.drawLine(Offset(size.width * 0.34, size.height * 0.62), Offset(size.width * 0.66, size.height * 0.62), stroke);

    final doc = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(size.width * 0.5, size.height * 0.78), width: 18, height: 14),
      const Radius.circular(2),
    );
    canvas.drawRRect(doc, stroke);
    canvas.drawLine(Offset(size.width * 0.44, size.height * 0.76), Offset(size.width * 0.56, size.height * 0.76), stroke);
    canvas.drawLine(Offset(size.width * 0.44, size.height * 0.80), Offset(size.width * 0.52, size.height * 0.80), stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BrandTitle extends StatelessWidget {
  const _BrandTitle({required this.appName});

  final String appName;

  @override
  Widget build(BuildContext context) {
    final name = appName.trim();
    final splitAt = name.toLowerCase().endsWith('crm') ? name.length - 3 : name.length;
    final prefix = name.substring(0, splitAt);
    final suffix = name.substring(splitAt);

    return Column(
      children: [
        RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.5),
            children: [
              TextSpan(text: prefix, style: const TextStyle(color: Color(0xFF0F172A))),
              if (suffix.isNotEmpty)
                TextSpan(text: suffix, style: const TextStyle(color: Color(0xFF1E88E5))),
            ],
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
