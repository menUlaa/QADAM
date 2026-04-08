import 'package:flutter/material.dart';
import 'package:internship_app2/l10n/strings.dart';
import 'package:internship_app2/screens/role_selection_screen.dart';
import 'package:internship_app2/services/api_service.dart';
import 'package:internship_app2/services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onSuccess;
  final UserRole role;
  const AuthScreen({
    super.key,
    required this.onSuccess,
    this.role = UserRole.student,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  bool _isLogin = true;
  bool _loading = false;
  bool _googleLoading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  String? _error;

  // Step 2 — university/specialty
  int _step = 0; // 0=credentials, 1=university
  String? _selectedUniversity;
  String? _selectedSpecialty;
  List<String> _universities = [];
  Map<String, List<String>> _specialtiesByCategory = {};
  bool _loadingUnis = false;

  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _confirmPass = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _authService = AuthService();
  final _api = ApiService();

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
    _fadeAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _confirmPass.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _switchMode() {
    setState(() {
      _isLogin = !_isLogin;
      _error = null;
      _step = 0;
    });
    _animCtrl.forward(from: 0);
  }

  Future<void> _loadUniversities() async {
    if (_universities.isNotEmpty) return;
    setState(() => _loadingUnis = true);
    try {
      final data = await _api.getUniversities();
      final unis = (data['universities'] as List? ?? []).cast<String>();
      final specs = (data['specialties'] as Map? ?? {})
          .map((k, v) => MapEntry(k as String, (v as List).cast<String>()));
      setState(() {
        _universities = unis;
        _specialtiesByCategory = specs;
      });
    } catch (_) {
      // ignore — user can still proceed
    } finally {
      if (mounted) setState(() => _loadingUnis = false);
    }
  }

  bool get _needsUniStep =>
      !_isLogin &&
      (widget.role == UserRole.student || widget.role == UserRole.graduate);

  Future<void> _submit() async {
    final email = _email.text.trim();
    final pass = _pass.text;

    // ── Step 0: validate basic fields ────────────────────────────────────────
    if (_step == 0) {
      if (email.isEmpty || !email.contains('@')) {
        setState(() => _error = tr('enter_email'));
        return;
      }
      if (pass.length < 6) {
        setState(() => _error = tr('password_min'));
        return;
      }
      if (!_isLogin) {
        if (_firstName.text.trim().isEmpty) {
          setState(() => _error = tr('enter_name'));
          return;
        }
        if (_lastName.text.trim().isEmpty) {
          setState(() => _error = tr('enter_last_name'));
          return;
        }
        if (_confirmPass.text != pass) {
          setState(() => _error = tr('passwords_no_match'));
          return;
        }
        // Go to university/specialty step for students & graduates
        if (_needsUniStep) {
          setState(() { _step = 1; _error = null; });
          _animCtrl.forward(from: 0);
          _loadUniversities();
          return;
        }
      }
    }

    setState(() { _loading = true; _error = null; });

    try {
      if (_isLogin) {
        await _authService.login(email: email, password: pass);
        widget.onSuccess();
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      } else {
        final result = await _authService.register(
          email: email,
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          password: pass,
          confirmPassword: _confirmPass.text,
          isGraduate: widget.role == UserRole.graduate,
          universityName: _selectedUniversity,
          specialty: _selectedSpecialty,
        );
        if (result.requiresVerification) {
          setState(() { _isLogin = true; _error = null; _step = 0; });
          _showVerifyNotice();
        } else {
          widget.onSuccess();
          if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
        }
      }
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      // Network / cold-start errors → friendlier wording
      final isNetwork = msg.contains('fetch') ||
          msg.contains('просыпается') ||
          msg.contains('SocketException') ||
          msg.contains('timeout') ||
          msg.contains('TimeoutException');
      setState(() => _error = isNetwork
          ? '⏳ Сервер просыпается — подождите 10 сек и попробуйте снова'
          : msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _googleLoading = true;
      _error = null;
    });
    try {
      await _authService.loginWithGoogle();
      widget.onSuccess();
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      if (msg != 'Вход через Google отменён') {
        setState(() => _error = msg);
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  void _showVerifyNotice() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('verify_notice')),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _openResetPassword() {
    final emailCtrl = TextEditingController(text: _email.text.trim());
    final passCtrl = TextEditingController();
    bool sending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
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
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(tr('reset_password_title'),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(tr('reset_password_subtitle'),
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF6B7280))),
                const SizedBox(height: 20),
                _buildField(
                  controller: emailCtrl,
                  label: tr('email'),
                  icon: Icons.email_outlined,
                  type: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                _buildField(
                  controller: passCtrl,
                  label: tr('new_password'),
                  icon: Icons.lock_outline,
                  obscure: true,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2164F3),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: sending
                        ? null
                        : () async {
                            if (emailCtrl.text.isEmpty ||
                                passCtrl.text.length < 6) { return; }
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
                                  content:
                                      const Text('Пароль успешно изменён'),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                ),
                              );
                            } catch (e) {
                              setModal(() => sending = false);
                            }
                          },
                    child: sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(tr('reset_btn'),
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width > 720;

    return Scaffold(
      backgroundColor:
          isDesktop ? const Color(0xFF2164F3) : const Color(0xFFF3F4F6),
      body: isDesktop ? _buildDesktop() : _buildMobile(),
    );
  }

  // ── Desktop: split layout ─────────────────────────────────────────────────

  Widget _buildDesktop() {
    return Row(
      children: [
        // ── Left brand panel ──────────────────────────────────────────────
        Expanded(
          flex: 5,
          child: Container(
            color: const Color(0xFF2164F3),
            padding: const EdgeInsets.all(48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Language switcher
                _LanguageSwitcher(dark: false),
                const Spacer(),

                // Brand
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.trending_up_rounded,
                      color: Colors.white, size: 36),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Qadam',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  tr('app_tagline'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),

                // Feature bullets
                ...[
                  ('search', tr('ob1_title'), tr('ob1_sub')),
                  ('send', tr('ob2_title'), tr('ob2_sub')),
                  ('track', tr('ob3_title'), tr('ob3_sub')),
                ].map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              item.$1 == 'search'
                                  ? Icons.search_rounded
                                  : item.$1 == 'send'
                                      ? Icons.send_rounded
                                      : Icons.track_changes_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.$2,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  item.$3,
                                  style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.65),
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),

                const Spacer(),
                Text(
                  '© ${DateTime.now().year} Qadam',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Right form panel ──────────────────────────────────────────────
        Expanded(
          flex: 4,
          child: Container(
            color: Colors.white,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(48),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: _buildForm(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Mobile: centered card ─────────────────────────────────────────────────

  Widget _buildMobile() {
    return SafeArea(
      child: Column(
        children: [
          // Top bar with language switcher
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Qadam',
                  style: TextStyle(
                    color: Color(0xFF2164F3),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                _LanguageSwitcher(dark: true),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildForm(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared form ───────────────────────────────────────────────────────────

  Widget _buildForm() {
    if (_step == 1) return _buildUniStep();

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            Text(
              _isLogin ? tr('login_title') : tr('register_title'),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _isLogin ? tr('login_subtitle') : tr('register_subtitle'),
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 12),
            // Role badge
            _RoleBadge(role: widget.role),
            const SizedBox(height: 20),

            // Fields
            if (!_isLogin) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildField(
                      controller: _firstName,
                      label: tr('first_name'),
                      icon: Icons.person_outline,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildField(
                      controller: _lastName,
                      label: tr('last_name'),
                      icon: Icons.person_outline,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            _buildField(
              controller: _email,
              label: tr('email'),
              icon: Icons.email_outlined,
              type: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            _buildField(
              controller: _pass,
              label: tr('password'),
              icon: Icons.lock_outline,
              obscure: _obscurePass,
              suffix: IconButton(
                icon: Icon(
                  _obscurePass
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                  color: const Color(0xFF9CA3AF),
                ),
                onPressed: () =>
                    setState(() => _obscurePass = !_obscurePass),
              ),
            ),
            if (!_isLogin) ...[
              const SizedBox(height: 12),
              _buildField(
                controller: _confirmPass,
                label: tr('confirm_password'),
                icon: Icons.lock_outline,
                obscure: _obscureConfirm,
                suffix: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                    color: const Color(0xFF9CA3AF),
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
            ],

            // Forgot password
            if (_isLogin) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _openResetPassword,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    tr('forgot_password'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2164F3),
                    ),
                  ),
                ),
              ),
            ],

            // Inline error
            if (_error != null) ...[
              const SizedBox(height: 14),
              _ErrorBanner(message: _error!),
            ],

            const SizedBox(height: 20),

            // Submit button
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2164F3),
                  disabledBackgroundColor: const Color(0xFFD1D5DB),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _isLogin ? tr('login_btn') : tr('register_btn'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // ── OR divider ─────────────────────────────────────────────────
            Row(
              children: [
                const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    tr('or_divider'),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF9CA3AF),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
              ],
            ),
            const SizedBox(height: 16),

            // ── Google button ──────────────────────────────────────────────
            _GoogleButton(
              label: tr('sign_in_google'),
              loading: _googleLoading,
              onPressed: (_loading || _googleLoading) ? null : _signInWithGoogle,
            ),

            const SizedBox(height: 20),

            // Switch mode
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _isLogin ? tr('no_account') : tr('has_account'),
                  style: const TextStyle(
                      fontSize: 14, color: Color(0xFF6B7280)),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: _switchMode,
                  child: Text(
                    _isLogin
                        ? tr('switch_to_register')
                        : tr('switch_to_login'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2164F3),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUniStep() {
    final allSpecialties = _specialtiesByCategory.values.expand((v) => v).toList();

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Back button
            GestureDetector(
              onTap: () { setState(() { _step = 0; _error = null; }); _animCtrl.forward(from: 0); },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back_ios_rounded, size: 14, color: Color(0xFF6B7280)),
                  SizedBox(width: 4),
                  Text('Назад', style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Ваше образование',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF111827), letterSpacing: -0.5),
            ),
            const SizedBox(height: 4),
            const Text(
              'Это поможет AI подобрать подходящие стажировки',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 24),

            // University picker
            _buildDropdownField(
              label: 'Университет',
              icon: Icons.account_balance_outlined,
              value: _selectedUniversity,
              items: _universities,
              loading: _loadingUnis,
              onChanged: (v) => setState(() => _selectedUniversity = v),
            ),
            const SizedBox(height: 12),

            // Specialty picker
            _buildDropdownField(
              label: 'Специальность',
              icon: Icons.school_outlined,
              value: _selectedSpecialty,
              items: allSpecialties,
              loading: _loadingUnis,
              onChanged: (v) => setState(() => _selectedSpecialty = v),
            ),

            const SizedBox(height: 8),
            const Text(
              'Можно пропустить и заполнить позже в профиле',
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
              textAlign: TextAlign.center,
            ),

            if (_error != null) ...[
              const SizedBox(height: 14),
              _ErrorBanner(message: _error!),
            ],

            const SizedBox(height: 24),

            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2164F3),
                  disabledBackgroundColor: const Color(0xFFD1D5DB),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Завершить регистрацию', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required bool loading,
    required ValueChanged<String?> onChanged,
  }) {
    return GestureDetector(
      onTap: loading || items.isEmpty ? null : () async {
        final picked = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => _SearchPickerSheet(label: label, items: items),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: value != null ? const Color(0xFF2164F3) : const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
            const SizedBox(width: 12),
            Expanded(
              child: loading
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(
                      value ?? label,
                      style: TextStyle(
                        fontSize: 14,
                        color: value != null ? const Color(0xFF111827) : const Color(0xFF9CA3AF),
                      ),
                    ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: value != null ? const Color(0xFF2164F3) : const Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType type = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: type,
      onChanged: (_) {
        if (_error != null) setState(() => _error = null);
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
            fontSize: 14, color: Color(0xFF6B7280)),
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: Color(0xFF2164F3), width: 1.5),
        ),
      ),
    );
  }
}

// ── Google sign-in button ─────────────────────────────────────────────────────

class _GoogleButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  const _GoogleButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFE5E7EB)),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          padding: EdgeInsets.zero,
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF2164F3)),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _GoogleLogo(size: 20),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final UserRole role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (role) {
      UserRole.student => (Icons.school_rounded, 'Студент', const Color(0xFF2164F3)),
      UserRole.graduate => (Icons.workspace_premium_rounded, 'Выпускник', const Color(0xFF10B981)),
      UserRole.company => (Icons.business_rounded, 'Компания', const Color(0xFFF59E0B)),
      UserRole.university => (Icons.account_balance_rounded, 'Университет', const Color(0xFF8B5CF6)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  final double size;
  const _GoogleLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    // Stylised multi-colour "G" matching Google's brand colours
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    const strokeW = 0.22; // fraction of diameter

    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    final sw = size.width * strokeW;

    void arc(Color c, double start, double sweep) {
      canvas.drawArc(
        rect.deflate(sw / 2),
        start,
        sweep,
        false,
        Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.butt,
      );
    }

    const pi = 3.14159265;
    // Google colours: blue, red, yellow, green — each ~90°
    arc(const Color(0xFF4285F4), -pi / 2, pi * 0.56);          // blue (top → right)
    arc(const Color(0xFF34A853), -pi / 2 + pi * 0.56, pi * 0.5); // green
    arc(const Color(0xFFFBBC05), -pi / 2 + pi * 1.06, pi * 0.44); // yellow
    arc(const Color(0xFFEA4335), -pi / 2 + pi * 1.5, pi * 0.5);  // red

    // Right-side horizontal bar (the crossbar of the "G")
    final barY = cy;
    final barX1 = cx;
    final barX2 = cx + r - sw / 2;
    canvas.drawLine(
      Offset(barX1, barY),
      Offset(barX2, barY),
      Paint()
        ..color = const Color(0xFF4285F4)
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.butt,
    );
  }

  @override
  bool shouldRepaint(_GoogleGPainter old) => false;
}

// ── Search picker bottom sheet ────────────────────────────────────────────────

class _SearchPickerSheet extends StatefulWidget {
  final String label;
  final List<String> items;
  const _SearchPickerSheet({required this.label, required this.items});

  @override
  State<_SearchPickerSheet> createState() => _SearchPickerSheetState();
}

class _SearchPickerSheetState extends State<_SearchPickerSheet> {
  final _search = TextEditingController();
  List<String> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.items;
    _search.addListener(() {
      final q = _search.text.toLowerCase();
      setState(() => _filtered = q.isEmpty
          ? widget.items
          : widget.items.where((s) => s.toLowerCase().contains(q)).toList());
    });
  }

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _search,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Поиск...',
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF9CA3AF)),
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2164F3), width: 1.5)),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filtered.length,
              itemBuilder: (_, i) => ListTile(
                title: Text(_filtered[i], style: const TextStyle(fontSize: 14)),
                onTap: () => Navigator.pop(context, _filtered[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Language switcher widget ──────────────────────────────────────────────────

class _LanguageSwitcher extends StatelessWidget {
  final bool dark;
  const _LanguageSwitcher({required this.dark});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: localeNotifier,
      builder: (_, lang, w) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final e in {'RU': 'ru', 'ҚЗ': 'kz', 'EN': 'en'}.entries)
            GestureDetector(
              onTap: () => setLocale(e.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: lang == e.value
                      ? (dark
                          ? const Color(0xFFEBF0FA)
                          : Colors.white.withValues(alpha: 0.2))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: lang == e.value
                        ? (dark
                            ? const Color(0xFF2164F3)
                            : Colors.white)
                        : (dark
                            ? const Color(0xFFD1D5DB)
                            : Colors.white.withValues(alpha: 0.4)),
                  ),
                ),
                child: Text(
                  e.key,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: lang == e.value
                        ? (dark ? const Color(0xFF2164F3) : Colors.white)
                        : (dark
                            ? const Color(0xFF6B7280)
                            : Colors.white.withValues(alpha: 0.75)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error banner — yellow for network/timeout, red for auth errors
// ─────────────────────────────────────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  bool get _isNetwork => message.startsWith('⏳');

  @override
  Widget build(BuildContext context) {
    final bg     = _isNetwork ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2);
    final border = _isNetwork ? const Color(0xFFFDE68A) : const Color(0xFFFECACA);
    final color  = _isNetwork ? const Color(0xFFB45309) : const Color(0xFFDC2626);
    final icon   = _isNetwork ? Icons.hourglass_top_rounded : Icons.error_outline;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
