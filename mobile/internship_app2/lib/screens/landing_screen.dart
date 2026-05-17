import 'package:flutter/material.dart';
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
            child: _Nav(onAuth: () => _goToAuth(context), isDesktop: isDesktop),
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
                  _CategoriesSection(
                    onTap: () => _goToAuth(context),
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
  final bool isDesktop;
  const _Nav({required this.onAuth, required this.isDesktop});

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
            _NavLink('Компаниям'),
            _NavLink('Университетам'),
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
          'assets/images/logo.png',
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
            'qadam',
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
  const _CategoriesSection(
      {required this.onTap, required this.isDesktop});

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
          vertical: 52, horizontal: isDesktop ? 56 : 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Популярные направления',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                    letterSpacing: -0.3),
              ),
              const SizedBox(height: 6),
              const Text(
                'Выбери область и найди стажировку по интересам',
                style: TextStyle(fontSize: 14, color: _body),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _items
                    .map((item) => _CategoryCard(
                          label: item.$1,
                          icon: item.$2,
                          color: item.$3,
                          onTap: onTap,
                        ))
                    .toList(),
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
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
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
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.color.withValues(alpha: 0.06)
                : _surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hovered
                  ? widget.color.withValues(alpha: 0.35)
                  : _border,
              width: 1.5,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                        color: widget.color.withValues(alpha: 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: widget.color.withValues(
                      alpha: _hovered ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(widget.icon,
                    size: 16, color: widget.color),
              ),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: _hovered ? widget.color : _ink,
                ),
              ),
              const SizedBox(width: 6),
              AnimatedOpacity(
                opacity: _hovered ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: Icon(Icons.arrow_forward_rounded,
                    size: 13, color: widget.color),
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
                      'assets/images/logo.png',
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
                      child: const Text('qadam',
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
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 20,
                  runSpacing: 8,
                  children: const [
                    _FooterLink('Справка'),
                    _FooterLink('Конфиденциальность'),
                    _FooterLink('Условия'),
                    _FooterLink('Компаниям'),
                    _FooterLink('Университетам'),
                    _FooterLink('О нас'),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  '© 2025 Qadam',
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
