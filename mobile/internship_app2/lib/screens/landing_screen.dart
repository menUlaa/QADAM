import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:internship_app2/screens/role_selection_screen.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _ink     = Color(0xFF0F172A); // headings
const _body    = Color(0xFF475569); // body text
const _muted   = Color(0xFF94A3B8); // muted / placeholders
const _blue    = Color(0xFF2563EB); // primary
const _violet  = Color(0xFF7C3AED); // gradient accent
const _green   = Color(0xFF16A34A); // CTA
const _border  = Color(0xFFE2E8F0); // subtle border
const _bg      = Color(0xFFFFFFFF);
const _surface = Color(0xFFF8FAFC); // card surface

// Gradient used on the headline accent word + stat numbers
const _brandGradient = LinearGradient(
  colors: [_blue, _violet],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

Widget _cursorPointer({required Widget child}) => MouseRegion(
      cursor: SystemMouseCursors.click,
      child: child,
    );

class LandingScreen extends StatelessWidget {
  final VoidCallback onStudentSuccess;
  const LandingScreen({super.key, required this.onStudentSuccess});

  void _goToAuth(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, a, _) =>
            RoleSelectionScreen(onStudentSuccess: onStudentSuccess),
        transitionsBuilder: (_, a, _, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  void _goToCompanies(BuildContext context) {
    Navigator.pushNamed(context, '/companies',
        arguments: () => _goToAuth(context));
  }

  void _goToUniversities(BuildContext context) {
    Navigator.pushNamed(context, '/universities',
        arguments: () => _goToAuth(context));
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final isDesktop = w > 768;

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(
            bottom: false,
            child: _Nav(
              onAuth: () => _goToAuth(context),
              onCompanies: () => _goToCompanies(context),
              onUniversities: () => _goToUniversities(context),
              isDesktop: isDesktop,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _HeroSection(
                    onAction: () => _goToAuth(context),
                    isDesktop: isDesktop,
                  ),
                  _StatsSection(isDesktop: isDesktop),
                  _HowItWorksSection(
                    onAction: () => _goToAuth(context),
                    isDesktop: isDesktop,
                  ),
                  _CategoriesSection(
                    onTap: () => _goToAuth(context),
                    isDesktop: isDesktop,
                  ),
                  _RolesSection(
                    onStudentTap: () => _goToAuth(context),
                    onCompanyTap: () => _goToAuth(context),
                    onUniversityTap: () => _goToUniversities(context),
                    isDesktop: isDesktop,
                  ),
                  const _Footer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nav
// ─────────────────────────────────────────────────────────────────────────────

class _Nav extends StatelessWidget {
  final VoidCallback onAuth;
  final VoidCallback onCompanies;
  final VoidCallback onUniversities;
  final bool isDesktop;
  const _Nav({
    required this.onAuth,
    required this.onCompanies,
    required this.onUniversities,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: _bg.withValues(alpha: 0.95),
        border: const Border(bottom: BorderSide(color: _border)),
      ),
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 56 : 20),
      child: Row(
        children: [
          const _Logo(),
          if (isDesktop) ...[
            const SizedBox(width: 32),
            _cursorPointer(child: GestureDetector(onTap: onCompanies, child: _NavLink('Компаниям'))),
            _cursorPointer(child: GestureDetector(onTap: onUniversities, child: _NavLink('Университетам'))),
          ],
          const Spacer(),
          TextButton(
            onPressed: onAuth,
            style: TextButton.styleFrom(
              foregroundColor: _body,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: Size.zero,
            ),
            child: const Text('Войти',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500, color: _body)),
          ),
          const SizedBox(width: 8),
          _GradientButton(
            label: 'Начать',
            onTap: onAuth,
            small: true,
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/logo.jpg',
          width: 32,
          height: 32,
          errorBuilder: (_, __, ___) => ShaderMask(
            shaderCallback: (b) => _brandGradient.createShader(b),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.trending_up_rounded,
                  color: Colors.white, size: 17),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ShaderMask(
          shaderCallback: (b) => _brandGradient.createShader(b),
          child: const Text(
            'Qadam',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _NavLink extends StatefulWidget {
  final String label;
  const _NavLink(this.label);

  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 150),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _hovered ? _blue : _body,
          ),
          child: Text(widget.label),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gradient button — reusable CTA
// ─────────────────────────────────────────────────────────────────────────────

class _GradientButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool small;
  final IconData? icon;
  const _GradientButton({
    required this.label,
    required this.onTap,
    this.small = false,
    this.icon,
  });

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final h = widget.small ? 36.0 : 48.0;
    final px = widget.small ? 18.0 : 28.0;
    final fontSize = widget.small ? 13.0 : 15.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: h,
          padding: EdgeInsets.symmetric(horizontal: px),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _hovered
                  ? [const Color(0xFF1D4ED8), const Color(0xFF6D28D9)]
                  : [_blue, _violet],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                        color: _blue.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 4))
                  ]
                : [
                    BoxShadow(
                        color: _blue.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (widget.icon != null) ...[
                const SizedBox(width: 6),
                Icon(widget.icon, color: Colors.white, size: fontSize + 2),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero
// ─────────────────────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final VoidCallback onAction;
  final bool isDesktop;
  const _HeroSection({required this.onAction, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Gradient blob — top right (blue)
        Positioned(
          top: -80,
          right: -120,
          child: Container(
            width: 480,
            height: 480,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _blue.withValues(alpha: 0.12),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Gradient blob — bottom left (violet)
        Positioned(
          bottom: -60,
          left: -80,
          child: Container(
            width: 380,
            height: 380,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _violet.withValues(alpha: 0.10),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Content
        Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            left: isDesktop ? 56 : 24,
            right: isDesktop ? 56 : 24,
            top: isDesktop ? 88 : 56,
            bottom: isDesktop ? 80 : 56,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Pill badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: _blue.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                          color: _blue.withValues(alpha: 0.18)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _green,
                            boxShadow: [
                              BoxShadow(
                                  color: _green.withValues(alpha: 0.5),
                                  blurRadius: 6)
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Платформа стажировок в Казахстане',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _blue,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: isDesktop ? 28 : 20),

                  // Headline with gradient accent
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: isDesktop ? 52 : 34,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                        height: 1.15,
                        letterSpacing: -1.0,
                      ),
                      children: [
                        const TextSpan(text: 'Найди стажировку,\nкоторая '),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: ShaderMask(
                            shaderCallback: (b) =>
                                _brandGradient.createShader(b),
                            child: Text(
                              'запустит карьеру',
                              style: TextStyle(
                                fontSize: isDesktop ? 52 : 34,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.15,
                                letterSpacing: -1.0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  Text(
                    'Создай профиль — и мы подберём стажировки\nпо твоим навыкам, интересам и городу.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isDesktop ? 17 : 15,
                      color: _body,
                      height: 1.6,
                    ),
                  ),

                  SizedBox(height: isDesktop ? 40 : 32),

                  // Search bar
                  _SearchBar(onTap: onAction, isDesktop: isDesktop),

                  const SizedBox(height: 18),

                  // Popular tags
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      const Text('Популярно: ',
                          style: TextStyle(
                              fontSize: 13,
                              color: _muted,
                              fontWeight: FontWeight.w400)),
                      ...[
                        'IT',
                        'Дизайн',
                        'Маркетинг',
                        'Финансы',
                        'HR'
                      ].map((tag) => _cursorPointer(
                            child: GestureDetector(
                              onTap: onAction,
                              child: Text(
                                tag,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: _blue,
                                  fontWeight: FontWeight.w500,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Color(0xFFBFDBFE),
                                ),
                              ),
                            ),
                          )),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search bar — modern card style
// ─────────────────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final VoidCallback onTap;
  final bool isDesktop;
  const _SearchBar({required this.onTap, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    if (!isDesktop) return _MobileSearch(onTap: onTap);
    return _DesktopSearch(onTap: onTap);
  }
}

class _DesktopSearch extends StatelessWidget {
  final VoidCallback onTap;
  const _DesktopSearch({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border, width: 1.5),
        boxShadow: [
          BoxShadow(
              color: _ink.withValues(alpha: 0.07),
              blurRadius: 24,
              offset: const Offset(0, 8)),
          BoxShadow(
              color: _ink.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: _SearchInputField(
              icon: Icons.search_rounded,
              hint: 'Должность, компания или навык',
              leftRound: true,
              onTap: onTap,
            ),
          ),
          Container(
              width: 1,
              margin: const EdgeInsets.symmetric(vertical: 14),
              color: _border),
          Expanded(
            flex: 4,
            child: _SearchInputField(
              icon: Icons.location_on_outlined,
              hint: 'Город или удалённо',
              leftRound: false,
              onTap: onTap,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(7),
            child: _GradientButton(
              label: 'Найти',
              onTap: onTap,
              icon: Icons.search_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchInputField extends StatefulWidget {
  final IconData icon;
  final String hint;
  final bool leftRound;
  final VoidCallback onTap;
  const _SearchInputField({
    required this.icon,
    required this.hint,
    required this.leftRound,
    required this.onTap,
  });

  @override
  State<_SearchInputField> createState() => _SearchInputFieldState();
}

class _SearchInputFieldState extends State<_SearchInputField> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.text,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _hovered
                ? const Color(0xFFF8FAFC)
                : Colors.transparent,
            borderRadius: BorderRadius.horizontal(
              left: widget.leftRound
                  ? const Radius.circular(11)
                  : Radius.zero,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              Icon(widget.icon,
                  size: 18,
                  color: _hovered ? _blue : _muted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.hint,
                  style: TextStyle(
                      fontSize: 14.5,
                      color: _hovered
                          ? _body
                          : _muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileSearch extends StatelessWidget {
  final VoidCallback onTap;
  const _MobileSearch({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _cursorPointer(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border, width: 1.5),
                boxShadow: [
                  BoxShadow(
                      color: _ink.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, size: 19, color: _muted),
                  const SizedBox(width: 10),
                  Text('Должность, компания или навык',
                      style: TextStyle(
                          fontSize: 14.5,
                          color: _muted.withValues(alpha: 0.8))),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: _GradientButton(
            label: 'Найти стажировку',
            onTap: onTap,
            icon: Icons.arrow_forward_rounded,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// How It Works
// ─────────────────────────────────────────────────────────────────────────────

class _HowItWorksSection extends StatelessWidget {
  final VoidCallback onAction;
  final bool isDesktop;
  const _HowItWorksSection({required this.onAction, required this.isDesktop});

  static const _steps = [
    (
      '1',
      'Зарегистрируйся',
      'Создай аккаунт за 1 минуту — имя, email, университет и специальность.',
      Icons.person_add_alt_1_outlined,
      Color(0xFF2563EB),
    ),
    (
      '2',
      'Заполни профиль',
      'Добавь навыки, загрузи CV и укажи интересующие тебя направления.',
      Icons.edit_note_rounded,
      Color(0xFF7C3AED),
    ),
    (
      '3',
      'Найди стажировку',
      'Просматривай вакансии, используй AI-ассистента и подай заявку в один клик.',
      Icons.search_rounded,
      Color(0xFF0891B2),
    ),
    (
      '4',
      'Получи оффер',
      'Отслеживай статус заявок и жди звонка от компании.',
      Icons.check_circle_outline_rounded,
      Color(0xFF16A34A),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      padding: EdgeInsets.symmetric(
          vertical: 64, horizontal: isDesktop ? 56 : 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: _blue.withValues(alpha: 0.18)),
                ),
                child: const Text(
                  'Как это работает',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _blue),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Четыре шага до первой стажировки',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isDesktop ? 28 : 22,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Весь процесс занимает меньше 5 минут',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: _body),
              ),
              SizedBox(height: isDesktop ? 48 : 36),
              isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _steps.asMap().entries.map((e) {
                        final isLast = e.key == _steps.length - 1;
                        return Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _StepCard(step: e.value)),
                              if (!isLast)
                                Padding(
                                  padding: const EdgeInsets.only(top: 28),
                                  child: Icon(Icons.arrow_forward_rounded,
                                      size: 18, color: _muted),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    )
                  : Column(
                      children: _steps.asMap().entries.map((e) {
                        final isLast = e.key == _steps.length - 1;
                        return Column(
                          children: [
                            _StepCard(step: e.value),
                            if (!isLast) ...[
                              const SizedBox(height: 4),
                              const Icon(Icons.arrow_downward_rounded,
                                  size: 18, color: _muted),
                              const SizedBox(height: 4),
                            ],
                          ],
                        );
                      }).toList(),
                    ),
              const SizedBox(height: 40),
              _GradientButton(
                label: 'Начать бесплатно',
                onTap: onAction,
                icon: Icons.arrow_forward_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final (String, String, String, IconData, Color) step;
  const _StepCard({required this.step});

  @override
  Widget build(BuildContext context) {
    final (num, title, desc, icon, color) = step;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const Spacer(),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  num,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: _ink)),
          const SizedBox(height: 6),
          Text(desc,
              style: const TextStyle(fontSize: 13, color: _body, height: 1.5)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stats
// ─────────────────────────────────────────────────────────────────────────────

class _StatsSection extends StatelessWidget {
  final bool isDesktop;
  const _StatsSection({required this.isDesktop});

  static const _stats = [
    ('3 200+', 'студентов нашли стажировку'),
    ('140+', 'компаний-партнёров'),
    ('18', 'университетов'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _surface,
      padding: EdgeInsets.symmetric(
          vertical: 40, horizontal: isDesktop ? 56 : 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: isDesktop
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: _stats
                      .map((s) => _StatItem(value: s.$1, label: s.$2))
                      .toList(),
                )
              : Column(
                  children: _stats
                      .expand((s) => [
                            _StatItem(value: s.$1, label: s.$2),
                            const SizedBox(height: 20),
                          ])
                      .toList()
                    ..removeLast(),
                ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShaderMask(
          shaderCallback: (b) => _brandGradient.createShader(b),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white, // masked by shader
              letterSpacing: -1,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                color: _body,
                fontWeight: FontWeight.w400)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Categories
// ─────────────────────────────────────────────────────────────────────────────

class _CategoriesSection extends StatelessWidget {
  final VoidCallback onTap;
  final bool isDesktop;
  const _CategoriesSection({required this.onTap, required this.isDesktop});

  static const _items = [
    ('IT и разработка',  Icons.code_rounded,            Color(0xFF2563EB)),
    ('Дизайн',           Icons.palette_outlined,         Color(0xFF7C3AED)),
    ('Финансы',          Icons.account_balance_outlined, Color(0xFF0891B2)),
    ('Маркетинг',        Icons.campaign_outlined,        Color(0xFFDC2626)),
    ('HR',               Icons.people_outlined,          Color(0xFFD97706)),
    ('Инжиниринг',       Icons.engineering_outlined,     Color(0xFF16A34A)),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      padding: EdgeInsets.symmetric(
          vertical: 56, horizontal: isDesktop ? 56 : 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Популярные направления',
                  style: GoogleFonts.inter(
                      fontSize: 22, fontWeight: FontWeight.w800,
                      color: _ink, letterSpacing: -0.4)),
              const SizedBox(height: 6),
              Text('Выбери область и найди стажировку по интересам',
                  style: GoogleFonts.inter(
                      fontSize: 14, color: _body)),
              const SizedBox(height: 28),
              isDesktop
                  ? Row(
                      children: _items.map((item) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: _CategoryCard(
                              label: item.$1, icon: item.$2,
                              color: item.$3, onTap: onTap),
                        ),
                      )).toList(),
                    )
                  : Wrap(
                      spacing: 10, runSpacing: 10,
                      children: _items.map((item) => _CategoryCard(
                          label: item.$1, icon: item.$2,
                          color: item.$3, onTap: onTap)).toList(),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _CategoryCard({
    required this.label, required this.icon,
    required this.color, required this.onTap,
  });

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: _hovered ? widget.color.withValues(alpha: 0.06) : _surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovered ? widget.color.withValues(alpha: 0.4) : _border,
              width: 1.5,
            ),
            boxShadow: _hovered
                ? [BoxShadow(color: widget.color.withValues(alpha: 0.1),
                    blurRadius: 14, offset: const Offset(0, 4))]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: _hovered ? 0.15 : 0.09),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(widget.icon, size: 18, color: widget.color),
              ),
              const SizedBox(height: 10),
              Text(widget.label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _hovered ? widget.color : _ink,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Roles — For Students / Companies / Universities
// ─────────────────────────────────────────────────────────────────────────────

class _RolesSection extends StatelessWidget {
  final VoidCallback onStudentTap;
  final VoidCallback onCompanyTap;
  final VoidCallback onUniversityTap;
  final bool isDesktop;
  const _RolesSection({
    required this.onStudentTap,
    required this.onCompanyTap,
    required this.onUniversityTap,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _surface,
      padding: EdgeInsets.symmetric(
          vertical: 56, horizontal: isDesktop ? 56 : 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: isDesktop
              ? LayoutBuilder(builder: (_, cst) {
                  final w = (cst.maxWidth - 24) / 3;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: w, child: _RoleCard(
                            title: 'Для студентов',
                            description: 'Найди стажировку, создай профиль и получи оффер от лучших компаний Казахстана',
                            icon: Icons.school_rounded,
                            colors: const [Color(0xFF2563EB), Color(0xFF3B82F6)],
                            cta: 'Найти стажировку →',
                            onTap: onStudentTap,
                          )),
                      const SizedBox(width: 12),
                      SizedBox(width: w, child: _RoleCard(
                            title: 'Для компаний',
                            description: 'Публикуй вакансии, управляй заявками и нанимай лучших стажёров',
                            icon: Icons.business_rounded,
                            colors: const [Color(0xFF1E293B), Color(0xFF334155)],
                            cta: 'Разместить вакансию →',
                            onTap: onCompanyTap,
                          )),
                      const SizedBox(width: 12),
                      SizedBox(width: w, child: _RoleCard(
                            title: 'Для университетов',
                            description: 'Отслеживай трудоустройство студентов и анализируй данные',
                            icon: Icons.account_balance_rounded,
                            colors: const [Color(0xFF7C3AED), Color(0xFF9333EA)],
                            cta: 'Войти в портал →',
                            onTap: onUniversityTap,
                          )),
                    ],
                  );
                })
              : Column(
                  children: [
                    _RoleCard(
                      title: 'Для студентов',
                      description: 'Ищи стажировки, создавай профиль и получай офферы от лучших компаний',
                      icon: Icons.school_rounded,
                      colors: const [Color(0xFF2563EB), Color(0xFF3B82F6)],
                      cta: 'Найти стажировку →',
                      onTap: onStudentTap,
                    ),
                    const SizedBox(height: 12),
                    _RoleCard(
                      title: 'Для компаний',
                      description: 'Публикуй стажировки, управляй кандидатами и нанимай таланты',
                      icon: Icons.business_rounded,
                      colors: const [Color(0xFF1E293B), Color(0xFF334155)],
                      cta: 'Разместить вакансию →',
                      onTap: onCompanyTap,
                    ),
                    const SizedBox(height: 12),
                    _RoleCard(
                      title: 'Для университетов',
                      description: 'Отслеживай трудоустройство студентов и анализируй статистику',
                      icon: Icons.account_balance_rounded,
                      colors: const [Color(0xFF7C3AED), Color(0xFF9333EA)],
                      cta: 'Войти в портал →',
                      onTap: onUniversityTap,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final List<Color> colors;
  final String cta;
  final VoidCallback onTap;
  const _RoleCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.colors,
    required this.cta,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _hovered
                    ? widget.colors.first.withValues(alpha: 0.38)
                    : Colors.black.withValues(alpha: 0.08),
                blurRadius: _hovered ? 22 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 20),
              Text(
                widget.title,
                style: GoogleFonts.inter(
                  fontSize: 18, fontWeight: FontWeight.w800,
                  color: Colors.white, letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: Text(
                  widget.description,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.82),
                    height: 1.55,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.cta,
                style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Footer
// ─────────────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _surface,
      child: Column(
        children: [
          Container(height: 1, color: _border),
          Padding(
            padding: const EdgeInsets.symmetric(
                vertical: 24, horizontal: 24),
            child: Column(
              children: [
                // Logo + tagline
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/logo.jpg',
                      width: 24,
                      height: 24,
                      errorBuilder: (_, _, _) => ShaderMask(
                        shaderCallback: (b) => _brandGradient.createShader(b),
                        child: const Icon(Icons.trending_up_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(width: 6),
                    ShaderMask(
                      shaderCallback: (b) =>
                          _brandGradient.createShader(b),
                      child: const Text('Qadam',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.3)),
                    ),
                    const SizedBox(width: 8),
                    const Text('—',
                        style:
                            TextStyle(fontSize: 13, color: _muted)),
                    const SizedBox(width: 8),
                    const Text('Стажировки в Казахстане',
                        style: TextStyle(fontSize: 13, color: _body)),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  '© 2026 Qadam',
                  style: TextStyle(fontSize: 12, color: _muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String label;
  const _FooterLink(this.label);

  @override
  Widget build(BuildContext context) {
    return _cursorPointer(
      child: Text(label,
          style: const TextStyle(
              fontSize: 12,
              color: _body,
              decoration: TextDecoration.underline,
              decorationColor: _border)),
    );
  }
}

