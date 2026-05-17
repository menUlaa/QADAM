import 'dart:async';
import 'package:flutter/material.dart';
import 'package:internship_app2/screens/auth_screen.dart';
import 'package:internship_app2/screens/university_login_screen.dart';
import 'package:internship_app2/screens/company_dashboard_screen.dart';
import 'package:internship_app2/services/auth_service.dart';
import 'package:internship_app2/services/api_service.dart';

enum UserRole { student, graduate, company, university }

// ── tokens ────────────────────────────────────────────────────────────────────
const _blue   = Color(0xFF2563EB);
const _ink    = Color(0xFF111827);
const _body   = Color(0xFF6B7280);
const _muted  = Color(0xFF9CA3AF);
const _border = Color(0xFFE5E7EB);
const _red    = Color(0xFFDC2626);

class RoleSelectionScreen extends StatefulWidget {
  final VoidCallback onStudentSuccess;
  const RoleSelectionScreen({super.key, required this.onStudentSuccess});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  final _emailCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _authService = AuthService();

  bool   _loading        = false;
  bool   _googleLoading  = false;
  bool   _obscurePass    = true;
  bool   _hintVisible    = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _authService.warmup();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // ── Login ─────────────────────────────────────────────────────────────────
  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final pass  = _passCtrl.text;
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Введите корректный email');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'Пароль — минимум 6 символов');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final hint = Timer(const Duration(seconds: 4), () {
      if (mounted && _loading) setState(() => _hintVisible = true);
    });
    try {
      await _authService.login(email: email, password: pass);
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      widget.onStudentSuccess();
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      final isNetwork = msg.contains('просыпается') ||
          msg.contains('timeout') || msg.contains('fetch');
      setState(() => _error = isNetwork
          ? '⏳ Сервер просыпается — подождите и попробуйте снова'
          : msg);
    } finally {
      hint.cancel();
      if (mounted) setState(() { _loading = false; _hintVisible = false; });
    }
  }

  // ── Google ────────────────────────────────────────────────────────────────
  Future<void> _signInWithGoogle() async {
    setState(() { _googleLoading = true; _error = null; });
    try {
      await _authService.loginWithGoogle();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      widget.onStudentSuccess();
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      if (msg != 'Вход через Google отменён') {
        setState(() => _error = msg);
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  // ── Go to registration ────────────────────────────────────────────────────
  void _goToRegister() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, _) => AuthScreen(
          onSuccess: widget.onStudentSuccess,
          role: UserRole.student,
          initialIsLogin: false,
        ),
        transitionsBuilder: (_, a, _, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  // ── Forgot password ───────────────────────────────────────────────────────
  void _openForgotPassword() {
    final emailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    final passCtrl  = TextEditingController();
    bool sending    = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: _border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Сброс пароля',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('Введите email и новый пароль',
                    style: TextStyle(fontSize: 13, color: _body)),
                const SizedBox(height: 20),
                _InputField(
                  controller: emailCtrl,
                  label: 'Email',
                  icon: Icons.email_outlined,
                  type: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                _InputField(
                  controller: passCtrl,
                  label: 'Новый пароль',
                  icon: Icons.lock_outline,
                  obscure: true,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _blue,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: sending
                        ? null
                        : () async {
                            if (emailCtrl.text.isEmpty ||
                                passCtrl.text.length < 6) {
                              return;
                            }
                            setModal(() => sending = true);
                            try {
                              await _authService.resetPassword(
                                email: emailCtrl.text.trim(),
                                newPassword: passCtrl.text,
                              );
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: const Text('Пароль изменён'),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: const Color(0xFF10B981),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                ),
                              );
                            } catch (_) {
                              setModal(() => sending = false);
                            }
                          },
                    child: sending
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : const Text('Сохранить пароль',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width > 600;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Color(0xFF374151)),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    isDesktop ? 40 : 24, 8,
                    isDesktop ? 40 : 24, 32,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      children: [
                        // Logo
                        _QadamLogo(),
                        const SizedBox(height: 28),

                        // Card
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(isDesktop ? 36 : 24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.07),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.stretch,
                            children: [
                              const Text('С возвращением!',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: _ink,
                                    letterSpacing: -0.5,
                                  )),
                              const SizedBox(height: 4),
                              const Text('Войдите в аккаунт Qadam',
                                  style: TextStyle(
                                      fontSize: 15, color: _body)),
                              const SizedBox(height: 24),

                              // Google
                              _GoogleBtn(
                                loading: _googleLoading,
                                onPressed: (_loading || _googleLoading)
                                    ? null
                                    : _signInWithGoogle,
                              ),
                              const SizedBox(height: 20),

                              // Divider
                              const Row(
                                children: [
                                  Expanded(
                                      child: Divider(color: _border)),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 14),
                                    child: Text('или',
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: _muted,
                                            fontWeight:
                                                FontWeight.w500)),
                                  ),
                                  Expanded(
                                      child: Divider(color: _border)),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Error
                              if (_error != null) ...[
                                _ErrorBanner(message: _error!),
                                const SizedBox(height: 12),
                              ],

                              // Email
                              _InputField(
                                controller: _emailCtrl,
                                label: 'Email',
                                icon: Icons.email_outlined,
                                type: TextInputType.emailAddress,
                                onChanged: () {
                                  if (_error != null) {
                                    setState(() => _error = null);
                                  }
                                },
                              ),
                              const SizedBox(height: 12),

                              // Password
                              _InputField(
                                controller: _passCtrl,
                                label: 'Пароль',
                                icon: Icons.lock_outline,
                                obscure: _obscurePass,
                                onChanged: () {
                                  if (_error != null) {
                                    setState(() => _error = null);
                                  }
                                },
                                onSubmitted: (_) => _login(),
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscurePass
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 18,
                                    color: _muted,
                                  ),
                                  onPressed: () => setState(
                                      () => _obscurePass = !_obscurePass),
                                ),
                              ),

                              // Forgot password
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _openForgotPassword,
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('Забыли пароль?',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: _blue)),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Login button
                              SizedBox(
                                height: 50,
                                child: FilledButton(
                                  onPressed:
                                      _loading ? null : _login,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _blue,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8)),
                                  ),
                                  child: _loading
                                      ? const SizedBox(
                                          width: 20, height: 20,
                                          child:
                                              CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white))
                                      : const Text('Войти',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight:
                                                  FontWeight.w700)),
                                ),
                              ),

                              if (_hintVisible)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    '⏳ Сервер просыпается, подождите...',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[500]),
                                  ),
                                ),

                              const SizedBox(height: 20),

                              // Register link
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  const Text('Нет аккаунта?',
                                      style: TextStyle(
                                          fontSize: 14, color: _body)),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: _goToRegister,
                                    child: const Text(
                                      'Зарегистрироваться',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: _blue,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Company / University
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 6,
                          children: [
                            const Text('Вы работодатель?',
                                style: TextStyle(
                                    fontSize: 13, color: _body)),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const _CompanyEntry()),
                              ),
                              child: const Text('Войти как компания',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _blue,
                                    decoration:
                                        TextDecoration.underline,
                                    decorationColor: _blue,
                                  )),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const UniversityLoginScreen()),
                          ),
                          child: const Text('Войти как университет',
                              style: TextStyle(
                                fontSize: 13,
                                color: _muted,
                                decoration: TextDecoration.underline,
                                decorationColor: Color(0xFFD1D5DB),
                              )),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          '© ${DateTime.now().year} Qadam · Стажировки в Казахстане',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFFD1D5DB)),
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
    );
  }
}

// ── Shared input field ─────────────────────────────────────────────────────────

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType type;
  final bool obscure;
  final Widget? suffix;
  final VoidCallback? onChanged;
  final ValueChanged<String>? onSubmitted;

  const _InputField({
    required this.controller,
    required this.label,
    required this.icon,
    this.type = TextInputType.text,
    this.obscure = false,
    this.suffix,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: type,
      obscureText: obscure,
      onChanged: onChanged != null ? (_) => onChanged!() : null,
      onSubmitted: onSubmitted,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 14, color: _body),
        prefixIcon: Icon(icon, size: 18, color: _muted),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _blue, width: 2),
        ),
      ),
    );
  }
}

// ── Error banner ───────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  bool get _isNetwork => message.startsWith('⏳');

  @override
  Widget build(BuildContext context) {
    final bg     = _isNetwork ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2);
    final border = _isNetwork ? const Color(0xFFFDE68A) : const Color(0xFFFECACA);
    final color  = _isNetwork ? const Color(0xFFB45309) : _red;
    final icon   = _isNetwork
        ? Icons.hourglass_top_rounded
        : Icons.error_outline;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: TextStyle(fontSize: 13, color: color))),
        ],
      ),
    );
  }
}

// ── Qadam logo ─────────────────────────────────────────────────────────────────

class _QadamLogo extends StatelessWidget {
  const _QadamLogo();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/logo.png',
          width: 32,
          height: 32,
          errorBuilder: (_, _, _) => Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF7C3AED)]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.trending_up_rounded,
                color: Colors.white, size: 18),
          ),
        ),
        const SizedBox(width: 8),
        ShaderMask(
          shaderCallback: (b) => const LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
          ).createShader(b),
          child: const Text('qadam',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              )),
        ),
      ],
    );
  }
}

// ── Google button ──────────────────────────────────────────────────────────────

class _GoogleBtn extends StatelessWidget {
  final bool loading;
  final VoidCallback? onPressed;
  const _GoogleBtn({required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: _border, width: 1.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
        child: loading
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: _blue))
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _GoogleIcon(size: 22),
                  SizedBox(width: 12),
                  Text('Продолжить через Google',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _ink)),
                ],
              ),
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  final double size;
  const _GoogleIcon({required this.size});

  @override
  Widget build(BuildContext context) => SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GPainter()));
}

class _GPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2;
    const sw = 0.22;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    final s    = size.width * sw;

    void arc(Color c, double start, double sweep) => canvas.drawArc(
          rect.deflate(s / 2), start, sweep, false,
          Paint()
            ..color = c
            ..style = PaintingStyle.stroke
            ..strokeWidth = s
            ..strokeCap = StrokeCap.butt,
        );

    const pi = 3.14159265;
    arc(const Color(0xFF4285F4), -pi / 2, pi * 0.56);
    arc(const Color(0xFF34A853), -pi / 2 + pi * 0.56, pi * 0.5);
    arc(const Color(0xFFFBBC05), -pi / 2 + pi * 1.06, pi * 0.44);
    arc(const Color(0xFFEA4335), -pi / 2 + pi * 1.5, pi * 0.5);
    canvas.drawLine(
      Offset(cx, cy), Offset(cx + r - s / 2, cy),
      Paint()
        ..color = const Color(0xFF4285F4)
        ..strokeWidth = s
        ..strokeCap = StrokeCap.butt,
    );
  }

  @override
  bool shouldRepaint(_GPainter _) => false;
}

// ── Company auth ───────────────────────────────────────────────────────────────

class _CompanyEntry extends StatefulWidget {
  const _CompanyEntry();

  @override
  State<_CompanyEntry> createState() => _CompanyEntryState();
}

class _CompanyEntryState extends State<_CompanyEntry> {
  final _api   = ApiService();
  bool _isLogin = true;
  bool _loading = false;
  String? _error;

  final _name  = TextEditingController();
  final _email = TextEditingController();
  final _pass  = TextEditingController();
  final _city  = TextEditingController();

  @override
  void dispose() {
    _name.dispose(); _email.dispose();
    _pass.dispose(); _city.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty || _pass.text.length < 6) {
      setState(() => _error = 'Введите email и пароль (мин. 6 символов)');
      return;
    }
    if (!_isLogin && _name.text.trim().isEmpty) {
      setState(() => _error = 'Введите название компании');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final Map<String, dynamic> data;
      if (_isLogin) {
        data = await _api.companyLogin(
            _email.text.trim(), _pass.text);
      } else {
        data = await _api.companyRegister({
          'name': _name.text.trim(),
          'email': _email.text.trim(),
          'password': _pass.text,
          'city': _city.text.trim(),
        });
      }
      final token = data['access_token'] as String;
      final companyName =
          (data['company'] as Map?)?['name'] as String? ??
              _name.text.trim();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CompanyDashboardScreen(
              token: token, companyName: companyName),
        ),
      );
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {TextInputType type = TextInputType.text, bool obscure = false}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: type,
      onChanged: (_) {
        if (_error != null) setState(() => _error = null);
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: _muted),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
                color: Color(0xFFF59E0B), width: 1.5)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Кабинет компании',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.business_rounded,
                      size: 32, color: Color(0xFFF59E0B)),
                ),
                const SizedBox(height: 20),
                Text(
                  _isLogin
                      ? 'Вход для компаний'
                      : 'Регистрация компании',
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: _ink),
                ),
                const SizedBox(height: 4),
                const Text(
                    'Размещайте вакансии и управляйте заявками',
                    style: TextStyle(fontSize: 13, color: _body)),
                const SizedBox(height: 24),
                if (!_isLogin) ...[
                  _field(_name, 'Название компании',
                      Icons.business_outlined),
                  const SizedBox(height: 10),
                  _field(_city, 'Город',
                      Icons.location_on_outlined),
                  const SizedBox(height: 10),
                ],
                _field(_email, 'Email', Icons.email_outlined,
                    type: TextInputType.emailAddress),
                const SizedBox(height: 10),
                _field(_pass, 'Пароль', Icons.lock_outline,
                    obscure: true),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFFFECACA)),
                    ),
                    child: Text(_error!,
                        style: const TextStyle(
                            fontSize: 13, color: _red)),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : Text(
                            _isLogin
                                ? 'Войти'
                                : 'Зарегистрироваться',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                        _isLogin
                            ? 'Нет аккаунта?'
                            : 'Уже есть аккаунт?',
                        style: const TextStyle(
                            fontSize: 14, color: _body)),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => setState(() {
                        _isLogin = !_isLogin;
                        _error = null;
                      }),
                      child: Text(
                        _isLogin
                            ? 'Зарегистрироваться'
                            : 'Войти',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
