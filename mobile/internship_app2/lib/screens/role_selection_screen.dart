import 'package:flutter/material.dart';
import 'package:internship_app2/l10n/strings.dart';
import 'package:internship_app2/screens/auth_screen.dart';
import 'package:internship_app2/screens/company_dashboard_screen.dart';
import 'package:internship_app2/screens/university_login_screen.dart';
import 'package:internship_app2/services/api_service.dart';

enum UserRole { student, graduate, company, university }

class RoleSelectionScreen extends StatefulWidget {
  final VoidCallback onStudentSuccess;

  const RoleSelectionScreen({super.key, required this.onStudentSuccess});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  UserRole? _selected;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onSelect(UserRole role) {
    setState(() => _selected = role);

    Future.delayed(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      switch (role) {
        case UserRole.student:
        case UserRole.graduate:
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (ctx, a, b) => AuthScreen(
                onSuccess: widget.onStudentSuccess,
                role: role,
              ),
              transitionsBuilder: (ctx, animation, b, child) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.05, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                      parent: animation, curve: Curves.easeOut)),
                  child: child,
                ),
              ),
              transitionDuration: const Duration(milliseconds: 280),
            ),
          ).then((_) => setState(() => _selected = null));
        case UserRole.company:
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (ctx, a, b) => const _CompanyComingSoonScreen(),
              transitionsBuilder: (ctx, animation, b, child) =>
                  FadeTransition(opacity: animation, child: child),
              transitionDuration: const Duration(milliseconds: 250),
            ),
          ).then((_) => setState(() => _selected = null));
        case UserRole.university:
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (ctx, a, b) => const UniversityLoginScreen(),
              transitionsBuilder: (ctx, animation, b, child) =>
                  FadeTransition(opacity: animation, child: child),
              transitionDuration: const Duration(milliseconds: 250),
            ),
          ).then((_) => setState(() => _selected = null));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width > 600;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F2166), Color(0xFF2164F3)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 80 : 24,
                    vertical: 32,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Logo
                        const Text(
                          'Qadam',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 48),

                        // Heading
                        const Text(
                          'Кто вы?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Выберите роль чтобы продолжить',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 36),

                        // Role cards
                        _RoleCard(
                          role: UserRole.student,
                          icon: Icons.school_rounded,
                          title: 'Студент / Выпускник',
                          subtitle: 'Ищу стажировку или работу',
                          color: const Color(0xFF3B82F6),
                          isSelected: _selected == UserRole.student,
                          onTap: () => _onSelect(UserRole.student),
                        ),
                        const SizedBox(height: 12),
                        _RoleCard(
                          role: UserRole.company,
                          icon: Icons.business_rounded,
                          title: 'Компания',
                          subtitle: 'Размещаю вакансии и стажировки',
                          color: const Color(0xFFF59E0B),
                          isSelected: _selected == UserRole.company,
                          onTap: () => _onSelect(UserRole.company),
                        ),
                        const SizedBox(height: 12),
                        _RoleCard(
                          role: UserRole.university,
                          icon: Icons.account_balance_rounded,
                          title: 'Университет',
                          subtitle: 'Управляю студентами и практиками',
                          color: const Color(0xFF8B5CF6),
                          isSelected: _selected == UserRole.university,
                          onTap: () => _onSelect(UserRole.university),
                        ),

                        const SizedBox(height: 40),
                        Center(
                          child: Text(
                            tr('app_tagline'),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatefulWidget {
  final UserRole role;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.role,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
    _scale = _ctrl;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.reverse(),
      onTapUp: (_) {
        _ctrl.forward();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.forward(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isSelected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.2),
              width: widget.isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Icon container
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? widget.color.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  widget.icon,
                  size: 26,
                  color: widget.isSelected ? widget.color : Colors.white,
                ),
              ),
              const SizedBox(width: 16),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: widget.isSelected
                            ? const Color(0xFF111827)
                            : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: widget.isSelected
                            ? const Color(0xFF6B7280)
                            : Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: widget.isSelected
                    ? widget.color
                    : Colors.white.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Company auth screen ───────────────────────────────────────────────────────

class _CompanyComingSoonScreen extends StatefulWidget {
  const _CompanyComingSoonScreen();

  @override
  State<_CompanyComingSoonScreen> createState() => _CompanyAuthScreenState();
}

class _CompanyAuthScreenState extends State<_CompanyComingSoonScreen> {
  final _api = ApiService();
  bool _isLogin = true;
  bool _loading = false;
  String? _error;

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _city = TextEditingController();

  @override
  void dispose() {
    _name.dispose(); _email.dispose(); _pass.dispose(); _city.dispose();
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
        data = await _api.companyLogin(_email.text.trim(), _pass.text);
      } else {
        data = await _api.companyRegister({
          'name': _name.text.trim(),
          'email': _email.text.trim(),
          'password': _pass.text,
          'city': _city.text.trim(),
        });
      }
      final token = data['access_token'] as String;
      final companyName = (data['company'] as Map?)?['name'] as String? ?? _name.text.trim();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CompanyDashboardScreen(token: token, companyName: companyName),
        ),
      );
    } catch (e) {
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Кабинет компании', style: TextStyle(fontWeight: FontWeight.w800)),
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
                  decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.business_rounded, size: 32, color: Color(0xFFF59E0B)),
                ),
                const SizedBox(height: 20),
                Text(
                  _isLogin ? 'Вход для компаний' : 'Регистрация компании',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
                ),
                const SizedBox(height: 4),
                const Text('Размещайте вакансии и управляйте заявками', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                const SizedBox(height: 24),
                if (!_isLogin) ...[
                  _field(_name, 'Название компании', Icons.business_outlined),
                  const SizedBox(height: 10),
                  _field(_city, 'Город', Icons.location_on_outlined),
                  const SizedBox(height: 10),
                ],
                _field(_email, 'Email', Icons.email_outlined, type: TextInputType.emailAddress),
                const SizedBox(height: 10),
                _field(_pass, 'Пароль', Icons.lock_outline, obscure: true),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFECACA))),
                    child: Text(_error!, style: const TextStyle(fontSize: 13, color: Color(0xFFDC2626))),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_isLogin ? 'Войти' : 'Зарегистрироваться', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_isLogin ? 'Нет аккаунта?' : 'Уже есть аккаунт?', style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => setState(() { _isLogin = !_isLogin; _error = null; }),
                      child: Text(
                        _isLogin ? 'Зарегистрироваться' : 'Войти',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFF59E0B)),
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

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {TextInputType type = TextInputType.text, bool obscure = false}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: type,
      onChanged: (_) { if (_error != null) setState(() => _error = null); },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.5)),
      ),
    );
  }
}
