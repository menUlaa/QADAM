import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _ink     = Color(0xFF0F172A);
const _body    = Color(0xFF475569);
const _muted   = Color(0xFF94A3B8);
const _blue    = Color(0xFF2563EB);
const _violet  = Color(0xFF7C3AED);
const _purple  = Color(0xFF7B2FBE); // university accent
const _border  = Color(0xFFE2E8F0);
const _bg      = Color(0xFFFFFFFF);
const _surface = Color(0xFFF8FAFC);

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
// UniversitiesPage
// ─────────────────────────────────────────────────────────────────────────────

class UniversitiesPage extends StatefulWidget {
  final VoidCallback onAuth;
  const UniversitiesPage({super.key, required this.onAuth});

  @override
  State<UniversitiesPage> createState() => _UniversitiesPageState();
}

class _UniversitiesPageState extends State<UniversitiesPage> {
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
                  _BenefitsSection(isDesktop: isDesktop),
                  _DashboardPreview(isDesktop: isDesktop),
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
    void toCompanies() =>
        Navigator.pushNamed(context, '/companies', arguments: onAuth);

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
            _NavLink('Студентам',     active: false, onTap: toHome),
            _NavLink('Компаниям',     active: false, onTap: toCompanies),
            _NavLink('Университетам', active: true,  onTap: null),
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
          _PurpleButton(label: 'Начать', onTap: onAuth, small: true),
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
    final color = widget.active ? _purple : (_hovered ? _purple : _body);
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
// Purple button
// ─────────────────────────────────────────────────────────────────────────────

class _PurpleButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool small;
  final IconData? icon;
  const _PurpleButton({required this.label, required this.onTap, this.small = false, this.icon});

  @override
  State<_PurpleButton> createState() => _PurpleButtonState();
}

class _PurpleButtonState extends State<_PurpleButton> {
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
                  ? [const Color(0xFF6B21A8), const Color(0xFF7E22CE)]
                  : [const Color(0xFF7B2FBE), const Color(0xFF9333EA)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: _hovered
                ? [BoxShadow(color: _purple.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 4))]
                : [BoxShadow(color: _purple.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.label,
                  style: TextStyle(
                      color: Colors.white, fontSize: fontSize, fontWeight: FontWeight.w600)),
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
// Hero Section
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
        // Blob top-right
        Positioned(
          top: -60,
          right: -100,
          child: Container(
            width: 420,
            height: 420,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [_purple.withValues(alpha: 0.10), Colors.transparent],
              ),
            ),
          ),
        ),
        // Blob bottom-left
        Positioned(
          bottom: -40,
          left: -80,
          child: Container(
            width: 340,
            height: 340,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [_violet.withValues(alpha: 0.07), Colors.transparent],
              ),
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            left: isDesktop ? 56 : 24,
            right: isDesktop ? 56 : 24,
            top: isDesktop ? 80 : 52,
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
                        Expanded(flex: 45, child: const _HeroStatsGrid()),
                      ],
                    )
                  : Column(
                      children: [
                        _HeroText(onScrollToCta: onScrollToCta, isDesktop: false),
                        const SizedBox(height: 40),
                        const _HeroStatsGrid(),
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
            color: const Color(0xFFF3EFFE),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: _purple.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _purple,
                  boxShadow: [BoxShadow(color: _purple.withValues(alpha: 0.45), blurRadius: 6)],
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Для университетов',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _purple),
              ),
            ],
          ),
        ),

        SizedBox(height: isDesktop ? 24 : 18),

        // Headline
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: isDesktop ? 44 : 30,
              fontWeight: FontWeight.w800,
              color: _ink,
              height: 1.18,
              letterSpacing: -0.9,
            ),
            children: [
              const TextSpan(text: 'Отслеживай\n'),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: Text(
                  'трудоустройство ',
                  style: TextStyle(
                    fontSize: isDesktop ? 44 : 30,
                    fontWeight: FontWeight.w800,
                    color: _purple,
                    height: 1.18,
                    letterSpacing: -0.9,
                  ),
                ),
              ),
              const TextSpan(text: 'своих\nстудентов'),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Text(
          'Qadam даёт университетам полную картину — кто из студентов где стажируется, какие навыки востребованы и как растёт карьера выпускников.',
          style: TextStyle(
            fontSize: isDesktop ? 15.5 : 14,
            color: _body,
            height: 1.65,
          ),
        ),

        SizedBox(height: isDesktop ? 36 : 28),

        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _PurpleButton(
              label: 'Подключить портал',
              onTap: onScrollToCta,
              icon: Icons.account_balance_rounded,
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
                        'Запросить демо',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600, color: _ink),
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

class _HeroStatsGrid extends StatelessWidget {
  const _HeroStatsGrid();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Row of 3 cards
        LayoutBuilder(builder: (_, cst) {
          final w = (cst.maxWidth - 24) / 3;
          return Row(
            children: [
              SizedBox(width: w, child: const _MiniStatCard(value: '18', label: 'университетов уже подключено')),
              const SizedBox(width: 12),
              SizedBox(width: w, child: const _MiniStatCard(value: '2 400+', label: 'студентов отслеживается')),
              const SizedBox(width: 12),
              SizedBox(width: w, child: const _MiniStatCard(value: '87%', label: 'находят стажировку за 3 мес.')),
            ],
          );
        }),
        const SizedBox(height: 12),
        // Wide card spanning full width
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7B2FBE), Color(0xFF9333EA)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final city in ['Алматы', 'Астана', 'Шымкент', 'Караганда'])
                Text(
                  city,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String value;
  final String label;
  const _MiniStatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EFFE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _purple.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: _purple,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(fontSize: 11.5, color: _body, height: 1.4)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Benefits — Что получает университет
// ─────────────────────────────────────────────────────────────────────────────

class _BenefitsSection extends StatelessWidget {
  final bool isDesktop;
  const _BenefitsSection({required this.isDesktop});

  static const _items = [
    (
      num: '1',
      title: 'Портал мониторинга',
      body: 'Дашборд с данными по каждому студенту: статус поиска, поданные заявки, офферы.',
      icon: Icons.monitor_rounded,
    ),
    (
      num: '2',
      title: 'Аналитика по рынку',
      body: 'Какие навыки и специальности востребованы компаниями Казахстана прямо сейчас.',
      icon: Icons.bar_chart_rounded,
    ),
    (
      num: '3',
      title: 'Отчёты для аккредитации',
      body: 'Автоматические отчёты по трудоустройству студентов для проверяющих органов.',
      icon: Icons.description_rounded,
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
                'Что получает университет',
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
                'Инструменты для университетов, которые заботятся о карьере студентов',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: _body),
              ),
              SizedBox(height: isDesktop ? 48 : 36),
              isDesktop
                  ? LayoutBuilder(builder: (_, cst) {
                      final w = (cst.maxWidth - 32) / 3;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (int i = 0; i < _items.length; i++) ...[
                            if (i > 0) const SizedBox(width: 16),
                            SizedBox(
                              width: w,
                              child: _BenefitCard(
                                num: _items[i].num,
                                title: _items[i].title,
                                body: _items[i].body,
                                icon: _items[i].icon,
                              ),
                            ),
                          ],
                        ],
                      );
                    })
                  : Column(
                      children: [
                        for (int i = 0; i < _items.length; i++) ...[
                          if (i > 0) const SizedBox(height: 16),
                          _BenefitCard(
                            num: _items[i].num,
                            title: _items[i].title,
                            body: _items[i].body,
                            icon: _items[i].icon,
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

class _BenefitCard extends StatelessWidget {
  final String num;
  final String title;
  final String body;
  final IconData icon;
  const _BenefitCard({
    required this.num,
    required this.title,
    required this.body,
    required this.icon,
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
          BoxShadow(
              color: _ink.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7B2FBE), Color(0xFF9333EA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    num,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
                ),
              ),
              const Spacer(),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _purple.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: _purple),
              ),
            ],
          ),
          const SizedBox(height: 18),
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
          Text(body,
              style: const TextStyle(fontSize: 13.5, color: _body, height: 1.6)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dashboard Preview
// ─────────────────────────────────────────────────────────────────────────────

class _DashboardPreview extends StatelessWidget {
  final bool isDesktop;
  const _DashboardPreview({required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      padding: EdgeInsets.symmetric(
          vertical: 72, horizontal: isDesktop ? 56 : 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            children: [
              Text(
                'Портал университета',
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
                'Всё в одном окне',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: _body),
              ),
              const SizedBox(height: 40),
              // Mock dashboard card
              Container(
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _border),
                  boxShadow: [
                    BoxShadow(
                        color: _ink.withValues(alpha: 0.07),
                        blurRadius: 32,
                        offset: const Offset(0, 12)),
                  ],
                ),
                child: Column(
                  children: [
                    // Dashboard top bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7B2FBE), Color(0xFF9333EA)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance_rounded,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 10),
                          Text(
                            'Портал университета — Qadam',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('Демо',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          // Metrics row
                          LayoutBuilder(builder: (_, cst) {
                            if (cst.maxWidth < 500) {
                              return Column(
                                children: const [
                                  _MetricChip(
                                      value: '1 240',
                                      label: 'Активных студентов',
                                      color: _purple),
                                  SizedBox(height: 10),
                                  _MetricChip(
                                      value: '318',
                                      label: 'Получили оффер',
                                      color: Color(0xFF16A34A)),
                                  SizedBox(height: 10),
                                  _MetricChip(
                                      value: '89',
                                      label: 'В процессе',
                                      color: Color(0xFF2563EB)),
                                ],
                              );
                            }
                            final w = (cst.maxWidth - 24) / 3;
                            return Row(
                              children: [
                                SizedBox(
                                    width: w,
                                    child: const _MetricChip(
                                        value: '1 240',
                                        label: 'Активных студентов',
                                        color: _purple)),
                                const SizedBox(width: 12),
                                SizedBox(
                                    width: w,
                                    child: const _MetricChip(
                                        value: '318',
                                        label: 'Получили оффер',
                                        color: Color(0xFF16A34A))),
                                const SizedBox(width: 12),
                                SizedBox(
                                    width: w,
                                    child: const _MetricChip(
                                        value: '89',
                                        label: 'В процессе',
                                        color: Color(0xFF2563EB))),
                              ],
                            );
                          }),
                          const SizedBox(height: 24),
                          // Table header
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: _purple.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                    flex: 3,
                                    child: Text('Студент',
                                        style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: _purple))),
                                Expanded(
                                    flex: 2,
                                    child: Text('Специальность',
                                        style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: _purple))),
                                Expanded(
                                    flex: 3,
                                    child: Text('Статус',
                                        style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: _purple))),
                                Expanded(
                                    flex: 3,
                                    child: Text('Компания',
                                        style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: _purple))),
                              ],
                            ),
                          ),
                          // Table rows
                          _TableRow(
                            name: 'Айгерим С.',
                            spec: 'IT',
                            status: 'Оффер получен',
                            statusColor: const Color(0xFF16A34A),
                            statusBg: const Color(0xFFDCFCE7),
                            company: 'Kaspi Bank',
                            isLast: false,
                          ),
                          _TableRow(
                            name: 'Данияр М.',
                            spec: 'Дизайн',
                            status: 'На собеседовании',
                            statusColor: const Color(0xFF2563EB),
                            statusBg: const Color(0xFFDBEAFE),
                            company: 'Kolesa Group',
                            isLast: false,
                          ),
                          _TableRow(
                            name: 'Зарина К.',
                            spec: 'Финансы',
                            status: 'Подала заявку',
                            statusColor: const Color(0xFFD97706),
                            statusBg: const Color(0xFFFEF3C7),
                            company: 'Halyk Bank',
                            isLast: false,
                          ),
                          _TableRow(
                            name: 'Тимур А.',
                            spec: 'Маркетинг',
                            status: 'В поиске',
                            statusColor: _muted,
                            statusBg: const Color(0xFFF1F5F9),
                            company: '—',
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _MetricChip({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
                fontSize: 22, fontWeight: FontWeight.w900, color: color, letterSpacing: -0.5),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 11.5, color: color.withValues(alpha: 0.8))),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  final String name;
  final String spec;
  final String status;
  final Color statusColor;
  final Color statusBg;
  final String company;
  final bool isLast;
  const _TableRow({
    required this.name,
    required this.spec,
    required this.status,
    required this.statusColor,
    required this.statusBg,
    required this.company,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: _border, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _purple.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      name[0],
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _purple),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(name,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500, color: _ink),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(spec,
                style: const TextStyle(fontSize: 13, color: _body)),
          ),
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: statusColor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(company,
                  style: const TextStyle(fontSize: 13, color: _body),
                  overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Features — Инструменты для деканата
// ─────────────────────────────────────────────────────────────────────────────

class _FeaturesSection extends StatelessWidget {
  final bool isDesktop;
  const _FeaturesSection({required this.isDesktop});

  static const _features = [
    (
      icon: Icons.file_download_rounded,
      title: 'Экспорт отчётов',
      body: 'Выгрузка данных в PDF и Excel для отчётности перед деканатом и проверяющими органами.',
    ),
    (
      icon: Icons.filter_alt_rounded,
      title: 'Фильтры по факультету',
      body: 'Смотри данные отдельно по каждому факультету, специальности или курсу.',
    ),
    (
      icon: Icons.notifications_active_rounded,
      title: 'Уведомления',
      body: 'Получай оповещения, когда студент получает оффер или меняет статус поиска.',
    ),
    (
      icon: Icons.lock_rounded,
      title: 'Безопасность данных',
      body: 'Доступ только авторизованным сотрудникам университета. Данные надёжно защищены.',
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
                'Инструменты для деканата',
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
                'Всё необходимое для работы с данными о студентах',
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
                              SizedBox(width: w, child: _FeatureCard(icon: _features[0].icon, title: _features[0].title, body: _features[0].body)),
                              const SizedBox(width: 20),
                              SizedBox(width: w, child: _FeatureCard(icon: _features[1].icon, title: _features[1].title, body: _features[1].body)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(width: w, child: _FeatureCard(icon: _features[2].icon, title: _features[2].title, body: _features[2].body)),
                              const SizedBox(width: 20),
                              SizedBox(width: w, child: _FeatureCard(icon: _features[3].icon, title: _features[3].title, body: _features[3].body)),
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
                                    icon: f.icon, title: f.title, body: f.body),
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
  final String title;
  final String body;
  const _FeatureCard({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _bg,
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
              color: _purple.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: _purple),
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
                Text(body,
                    style:
                        const TextStyle(fontSize: 13.5, color: _body, height: 1.6)),
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
          colors: [Color(0xFF3B0764), Color(0xFF1E1035)],
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
                  'Бесплатно для университетов-партнёров',
                  style: TextStyle(
                      fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Подключите университет\nк Qadam',
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
                'Оставьте заявку — мы проведём демо и настроим портал под ваш вуз.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.white60, height: 1.6),
              ),
              const SizedBox(height: 32),
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
                          hintText: 'university@edu.kz',
                          hintStyle: TextStyle(color: _muted, fontSize: 14),
                          border: InputBorder.none,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 20),
                          prefixIcon: Icon(Icons.mail_outline_rounded,
                              color: _muted, size: 18),
                        ),
                        onSubmitted: (_) => _submitEmail(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: SizedBox(
                        height: 44,
                        child: _PurpleButton(
                          label: 'Оставить заявку',
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
                'Мы свяжемся в течение одного рабочего дня.',
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
                            letterSpacing: -0.3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('—',
                        style: TextStyle(fontSize: 13, color: _muted)),
                    const SizedBox(width: 8),
                    const Text('Стажировки в Казахстане',
                        style: TextStyle(fontSize: 13, color: _body)),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('© 2026 Qadam',
                    style: TextStyle(fontSize: 12, color: _muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
