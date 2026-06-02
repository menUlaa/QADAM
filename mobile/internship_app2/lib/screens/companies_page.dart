import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

// ── Design tokens (mirrors landing_screen.dart) ───────────────────────────────
const _ink    = Color(0xFF0F172A);
const _body   = Color(0xFF475569);
const _muted  = Color(0xFF94A3B8);
const _blue   = Color(0xFF2563EB);
const _violet = Color(0xFF7C3AED);
const _green  = Color(0xFF16A34A);
const _border = Color(0xFFE2E8F0);
const _bg     = Color(0xFFFFFFFF);
const _surface= Color(0xFFF8FAFC);

const _brandGradient = LinearGradient(
  colors: [_blue, _violet],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

Widget _cursorPointer({required Widget child}) => MouseRegion(
  cursor: SystemMouseCursors.click,
  child: child,
);

// ─────────────────────────────────────────────────────────────────────────────
// CompaniesPage
// ─────────────────────────────────────────────────────────────────────────────

class CompaniesPage extends StatefulWidget {
  final VoidCallback onAuth;
  const CompaniesPage({super.key, required this.onAuth});

  @override
  State<CompaniesPage> createState() => _CompaniesPageState();
}

class _CompaniesPageState extends State<CompaniesPage> {
  final _contactKey = GlobalKey();

  void _scrollToContact() {
    final ctx = _contactKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    }
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
            child: _Nav(onAuth: widget.onAuth, isDesktop: isDesktop),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _HeroSection(onScrollToCta: _scrollToContact, isDesktop: isDesktop),
                  _StepsSection(isDesktop: isDesktop),
                  _FeaturesSection(isDesktop: isDesktop),
                  _CtaSection(key: _contactKey, isDesktop: isDesktop),
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
    void toHome() => Navigator.of(context).popUntil((r) => r.isFirst);
    void toUniversities() =>
        Navigator.pushNamed(context, '/universities', arguments: onAuth);

    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: _bg.withValues(alpha: 0.95),
        border: const Border(bottom: BorderSide(color: _border)),
      ),
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 56 : 20),
      child: Row(
        children: [
          _cursorPointer(
            child: GestureDetector(onTap: toHome, child: const _Logo()),
          ),
          if (isDesktop) ...[
            const SizedBox(width: 32),
            _NavLink('Студентам',    active: false, onTap: toHome),
            _NavLink('Компаниям',    active: true,  onTap: null),
            _NavLink('Университетам',active: false, onTap: toUniversities),
          ],
          const Spacer(),
          TextButton(
            onPressed: onAuth,
            style: TextButton.styleFrom(
              foregroundColor: _body,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: Size.zero,
            ),
            child: const Text('Войти',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _body)),
          ),
          const SizedBox(width: 8),
          _GradientButton(label: 'Начать', onTap: onAuth, small: true),
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
          errorBuilder: (_, _, _) => ShaderMask(
            shaderCallback: (b) => _brandGradient.createShader(b),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.trending_up_rounded, color: Colors.white, size: 17),
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
  final bool active;
  final VoidCallback? onTap;
  const _NavLink(this.label, {required this.active, required this.onTap});

  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.active
        ? _blue
        : (_hovered ? _blue : _body);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            style: TextStyle(
              fontSize: 14,
              fontWeight: widget.active ? FontWeight.w600 : FontWeight.w500,
              color: color,
            ),
            child: Text(widget.label),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gradient button
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
                ? [BoxShadow(color: _blue.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 4))]
                : [BoxShadow(color: _blue.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))],
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
// Hero Section — two-column on desktop
// ─────────────────────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final VoidCallback onScrollToCta;
  final bool isDesktop;
  const _HeroSection({required this.onScrollToCta, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: -80,
          right: -120,
          child: Container(
            width: 480,
            height: 480,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [_blue.withValues(alpha: 0.10), Colors.transparent],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -60,
          left: -80,
          child: Container(
            width: 380,
            height: 380,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [_violet.withValues(alpha: 0.08), Colors.transparent],
              ),
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            left:   isDesktop ? 56 : 24,
            right:  isDesktop ? 56 : 24,
            top:    isDesktop ? 80 : 52,
            bottom: isDesktop ? 80 : 52,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(flex: 55, child: _HeroText(onScrollToCta: onScrollToCta, isDesktop: true)),
                        const SizedBox(width: 48),
                        Expanded(flex: 45, child: const _StatsGrid()),
                      ],
                    )
                  : Column(
                      children: [
                        _HeroText(onScrollToCta: onScrollToCta, isDesktop: false),
                        const SizedBox(height: 40),
                        const _StatsGrid(),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroText extends StatelessWidget {
  final VoidCallback onScrollToCta;
  final bool isDesktop;
  const _HeroText({required this.onScrollToCta, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _blue.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: _blue.withValues(alpha: 0.18)),
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
                  boxShadow: [BoxShadow(color: _green.withValues(alpha: 0.5), blurRadius: 6)],
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Для работодателей',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _blue),
              ),
            ],
          ),
        ),

        SizedBox(height: isDesktop ? 24 : 18),

        // Headline
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: isDesktop ? 46 : 32,
              fontWeight: FontWeight.w800,
              color: _ink,
              height: 1.15,
              letterSpacing: -1.0,
            ),
            children: [
              const TextSpan(text: 'Найди лучших\n'),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: ShaderMask(
                  shaderCallback: (b) => _brandGradient.createShader(b),
                  child: Text(
                    'стажёров Казахстана',
                    style: TextStyle(
                      fontSize: isDesktop ? 46 : 32,
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

        const SizedBox(height: 16),

        Text(
          'Публикуй стажировки, получай заявки от студентов лучших вузов Казахстана и нанимай быстро.',
          style: TextStyle(
            fontSize: isDesktop ? 16 : 14,
            color: _body,
            height: 1.65,
          ),
        ),

        SizedBox(height: isDesktop ? 36 : 28),

        // CTA buttons
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _GradientButton(
              label: 'Разместить вакансию',
              onTap: onScrollToCta,
              icon: Icons.add_rounded,
            ),
            _cursorPointer(
              child: GestureDetector(
                onTap: onScrollToCta,
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: _bg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _border, width: 1.5),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Узнать подробнее',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid();

  static const _stats = [
    (Icons.people_rounded,       '3 200+', 'студентов на платформе', Color(0xFF2563EB)),
    (Icons.business_rounded,     '140+',   'компаний-партнёров',     Color(0xFF7C3AED)),
    (Icons.account_balance_rounded,'18',   'университетов',          Color(0xFF0891B2)),
    (Icons.star_rounded,         '4.8★',   'средний рейтинг',        Color(0xFFD97706)),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: _stats
          .map((s) => _StatCard(icon: s.$1, value: s.$2, label: s.$3, color: s.$4))
          .toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: _ink,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: _body),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Steps Section — Три шага до стажёра
// ─────────────────────────────────────────────────────────────────────────────

class _StepsSection extends StatelessWidget {
  final bool isDesktop;
  const _StepsSection({required this.isDesktop});

  static const _steps = [
    (
      icon: Icons.edit_note_rounded,
      title: 'Создай профиль компании',
      body:  'Заполни информацию о компании и добавь стажировку за 5 минут. Никаких сложных форм.',
    ),
    (
      icon: Icons.inbox_rounded,
      title: 'Получай заявки',
      body:  'Студенты видят твою вакансию и откликаются. Ты получаешь их профили и резюме сразу.',
    ),
    (
      icon: Icons.handshake_rounded,
      title: 'Выбери и нанимай',
      body:  'Фильтруй кандидатов, общайся напрямую и делай офер лучшим — всё в одном месте.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _surface,
      padding: EdgeInsets.symmetric(
          vertical: 72, horizontal: isDesktop ? 56 : 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            children: [
              Text(
                'Три шага до стажёра',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: isDesktop ? 32 : 24,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Простой процесс от публикации до найма',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: _body),
              ),
              SizedBox(height: isDesktop ? 48 : 36),
              isDesktop
                  ? LayoutBuilder(builder: (_, cst) {
                      final w = (cst.maxWidth - 32) / 3;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (int i = 0; i < _steps.length; i++) ...[
                            if (i > 0) const SizedBox(width: 16),
                            SizedBox(
                              width: w,
                              child: _StepCard(
                                step: i + 1,
                                icon: _steps[i].icon,
                                title: _steps[i].title,
                                body: _steps[i].body,
                              ),
                            ),
                          ],
                        ],
                      );
                    })
                  : Column(
                      children: [
                        for (int i = 0; i < _steps.length; i++) ...[
                          if (i > 0) const SizedBox(height: 16),
                          _StepCard(
                            step: i + 1,
                            icon: _steps[i].icon,
                            title: _steps[i].title,
                            body: _steps[i].body,
                          ),
                        ],
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final int step;
  final IconData icon;
  final String title;
  final String body;
  const _StepCard({
    required this.step,
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(color: _ink.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ShaderMask(
                shaderCallback: (b) => _brandGradient.createShader(b),
                child: Text(
                  '0$step',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 20, color: _blue),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _ink,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(fontSize: 13.5, color: _body, height: 1.6),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Features Section — 2x2 grid
// ─────────────────────────────────────────────────────────────────────────────

class _FeaturesSection extends StatelessWidget {
  final bool isDesktop;
  const _FeaturesSection({required this.isDesktop});

  static const _features = [
    (
      icon: Icons.dashboard_rounded,
      color: Color(0xFF2563EB),
      title: 'Единый дашборд',
      body: 'Все заявки, кандидаты и вакансии в одном месте. Никаких таблиц и Excel.',
    ),
    (
      icon: Icons.tune_rounded,
      color: Color(0xFF7C3AED),
      title: 'Умные фильтры',
      body: 'Фильтруй студентов по навыкам, университету, городу и GPA.',
    ),
    (
      icon: Icons.bar_chart_rounded,
      color: Color(0xFF0891B2),
      title: 'Аналитика найма',
      body: 'Отслеживай конверсию воронки и улучшай результаты набора.',
    ),
    (
      icon: Icons.chat_bubble_outline_rounded,
      color: Color(0xFF16A34A),
      title: 'Прямые контакты',
      body: 'Связывайся со студентами напрямую — без посредников и лишних шагов.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      padding: EdgeInsets.symmetric(
          vertical: 72, horizontal: isDesktop ? 56 : 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            children: [
              Text(
                'Всё для удобного найма',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: isDesktop ? 32 : 24,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Инструменты, которые экономят твоё время',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: _body),
              ),
              SizedBox(height: isDesktop ? 48 : 36),
              isDesktop
                  ? LayoutBuilder(builder: (_, cst) {
                      final w = (cst.maxWidth - 20) / 2;
                      return Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: w,
                                child: _FeatureCard(
                                  icon: _features[0].icon,
                                  color: _features[0].color,
                                  title: _features[0].title,
                                  body: _features[0].body,
                                ),
                              ),
                              const SizedBox(width: 20),
                              SizedBox(
                                width: w,
                                child: _FeatureCard(
                                  icon: _features[1].icon,
                                  color: _features[1].color,
                                  title: _features[1].title,
                                  body: _features[1].body,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: w,
                                child: _FeatureCard(
                                  icon: _features[2].icon,
                                  color: _features[2].color,
                                  title: _features[2].title,
                                  body: _features[2].body,
                                ),
                              ),
                              const SizedBox(width: 20),
                              SizedBox(
                                width: w,
                                child: _FeatureCard(
                                  icon: _features[3].icon,
                                  color: _features[3].color,
                                  title: _features[3].title,
                                  body: _features[3].body,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    })
                  : Column(
                      children: _features
                          .map((f) => Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _FeatureCard(
                                  icon: f.icon,
                                  color: f.color,
                                  title: f.title,
                                  body: f.body,
                                ),
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

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _FeatureCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: const TextStyle(fontSize: 13.5, color: _body, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CTA Section
// ─────────────────────────────────────────────────────────────────────────────

class _CtaSection extends StatefulWidget {
  final bool isDesktop;
  const _CtaSection({super.key, required this.isDesktop});

  @override
  State<_CtaSection> createState() => _CtaSectionState();
}

class _CtaSectionState extends State<_CtaSection> {
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitEmail() async {
    final email = _emailCtrl.text.trim();
    final uri = Uri(
      scheme: 'mailto',
      path: 'karimovula06@gmail.com',
      queryParameters: {
        'subject': 'Заявка с сайта Qadam',
        'body': 'Email: $email',
      },
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          vertical: 80, horizontal: widget.isDesktop ? 56 : 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                ),
                child: const Text(
                  'Бесплатно для работодателей',
                  style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Готовы найти\nлучшего стажёра?',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: widget.isDesktop ? 36 : 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.8,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Оставь email — мы пришлём инструкцию по созданию первой вакансии.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.white60, height: 1.6),
              ),
              const SizedBox(height: 32),
              // Email row
              Container(
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 8)),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _emailCtrl,
                        style: const TextStyle(fontSize: 14, color: _ink),
                        decoration: const InputDecoration(
                          hintText: 'company@example.com',
                          hintStyle: TextStyle(color: _muted, fontSize: 14),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 20),
                          prefixIcon: Icon(Icons.mail_outline_rounded, color: _muted, size: 18),
                        ),
                        onSubmitted: (_) => _submitEmail(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: SizedBox(
                        height: 44,
                        child: _GradientButton(
                          label: 'Начать',
                          onTap: _submitEmail,
                          icon: Icons.arrow_forward_rounded,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Размещение вакансий бесплатно. Регистрация займёт 2 минуты.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.white38),
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
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
            child: Column(
              children: [
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
                      shaderCallback: (b) => _brandGradient.createShader(b),
                      child: const Text(
                        'Qadam',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('—', style: TextStyle(fontSize: 13, color: _muted)),
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
