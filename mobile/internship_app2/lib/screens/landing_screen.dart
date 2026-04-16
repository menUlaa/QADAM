import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:internship_app2/screens/role_selection_screen.dart';

const _blue = Color(0xFF2164F3);
const _purple = Color(0xFF6D28D9);
const _green = Color(0xFF10B981);

class LandingScreen extends StatefulWidget {
  final VoidCallback onStudentSuccess;
  const LandingScreen({super.key, required this.onStudentSuccess});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _heroCtrl;
  late final AnimationController _tickerCtrl;
  late final Animation<double> _heroFade;
  late final Animation<Offset> _heroSlide;

  int _tickerIndex = 0;

  static const _tickerItems = [
    '🎉 Kaspi Bank открыл стажировку для разработчиков',
    '📌 Kolesa Group ищет дизайнеров',
    '✅ 12 студентов получили офферы сегодня',
    '🚀 Freedom Finance — стажировка в финтехе',
    '💡 Jusan Bank: Data Analyst Intern',
  ];

  @override
  void initState() {
    super.initState();
    _heroCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _heroFade = CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut);
    _heroSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut));

    _tickerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          setState(() => _tickerIndex =
              (_tickerIndex + 1) % _tickerItems.length);
          _tickerCtrl.reset();
          _tickerCtrl.forward();
        }
      });

    _heroCtrl.forward();
    Future.delayed(const Duration(milliseconds: 1200),
        () => _tickerCtrl.forward());
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    _tickerCtrl.dispose();
    super.dispose();
  }

  void _goToAuth() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, a, _) =>
            RoleSelectionScreen(onStudentSuccess: widget.onStudentSuccess),
        transitionsBuilder: (_, a, _, child) => FadeTransition(
          opacity: a,
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final isDesktop = w > 900;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildNav(isDesktop)),
          SliverToBoxAdapter(child: _buildHero(isDesktop)),
          SliverToBoxAdapter(child: _buildTicker()),
          SliverToBoxAdapter(child: _buildStats()),
          SliverToBoxAdapter(child: _buildHowItWorks()),
          SliverToBoxAdapter(child: _buildForWhom(isDesktop)),
          SliverToBoxAdapter(child: _buildTestimonial()),
          SliverToBoxAdapter(child: _buildFinalCta()),
          SliverToBoxAdapter(child: _buildFooter()),
        ],
      ),
    );
  }

  // ── Navigation bar ─────────────────────────────────────────────────────────
  Widget _buildNav(bool isDesktop) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 80 : 20,
        vertical: 16,
      ),
      child: Row(
        children: [
          _Logo(),
          const Spacer(),
          if (isDesktop) ...[
            _NavLink('О продукте'),
            _NavLink('Компаниям'),
            _NavLink('Университетам'),
            const SizedBox(width: 16),
          ],
          OutlinedButton(
            onPressed: _goToAuth,
            style: OutlinedButton.styleFrom(
              foregroundColor: _blue,
              side: const BorderSide(color: _blue),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('Войти',
                style:
                    TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  // ── Hero section ───────────────────────────────────────────────────────────
  Widget _buildHero(bool isDesktop) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF0F4FF), Color(0xFFF5F3FF), Colors.white],
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 80 : 24,
        vertical: isDesktop ? 80 : 48,
      ),
      child: FadeTransition(
        opacity: _heroFade,
        child: SlideTransition(
          position: _heroSlide,
          child: isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 6, child: _heroText()),
                    const SizedBox(width: 60),
                    Expanded(flex: 5, child: _heroCard()),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _heroText(),
                    const SizedBox(height: 40),
                    _heroCard(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _heroText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _blue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _blue.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: _green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Платформа стажировок №1 в Казахстане',
                style: TextStyle(
                  color: _blue,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Найди стажировку.\nПрокачай карьеру.',
          style: GoogleFonts.inter(
            fontSize: 44,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF0F172A),
            height: 1.1,
            letterSpacing: -1.5,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Qadam — первый шаг в твоей карьере. AI подберёт стажировки, поможет составить резюме и подготовит к собеседованию.',
          style: TextStyle(
            fontSize: 16,
            color: const Color(0xFF64748B),
            height: 1.6,
          ),
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _HeroCta(
              label: 'Найти стажировку',
              icon: Icons.search_rounded,
              onTap: _goToAuth,
              primary: true,
            ),
            _HeroCta(
              label: 'Разместить вакансию',
              icon: Icons.add_business_rounded,
              onTap: _goToAuth,
              primary: false,
            ),
          ],
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 24,
          runSpacing: 8,
          children: [
            _statBadge('3 200+', 'студентов'),
            _statBadge('140+', 'компаний'),
            _statBadge('18', 'университетов'),
          ],
        ),
      ],
    );
  }

  Widget _statBadge(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            )),
        Text(label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            )),
      ],
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('AI подбор',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _blue)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Новые',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF15803D))),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._demoCards(),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _goToAuth,
              style: FilledButton.styleFrom(
                backgroundColor: _blue,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Смотреть все вакансии',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _demoCards() {
    const cards = [
      _DemoJob(
          company: 'Kaspi Bank',
          role: 'Junior iOS Developer',
          salary: '200K ₸',
          match: 92,
          tag: 'IT'),
      _DemoJob(
          company: 'Kolesa Group',
          role: 'Product Designer Intern',
          salary: '180K ₸',
          match: 85,
          tag: 'Дизайн'),
      _DemoJob(
          company: 'Halyk Bank',
          role: 'Data Analyst Intern',
          salary: '150K ₸',
          match: 78,
          tag: 'Финансы'),
    ];
    return cards.map((c) => _DemoJobCard(job: c)).toList();
  }

  // ── Live ticker ────────────────────────────────────────────────────────────
  Widget _buildTicker() {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: child,
        ),
        child: Text(
          _tickerItems[_tickerIndex],
          key: ValueKey(_tickerIndex),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ── Stats row ──────────────────────────────────────────────────────────────
  Widget _buildStats() {
    final stats = [
      ('3 200+', 'Студентов'),
      ('93%', 'Трудоустройство'),
      ('140+', 'Компаний-партнёров'),
      ('18', 'Университетов'),
    ];
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 40,
        runSpacing: 24,
        children: stats
            .map((s) => Column(
                  children: [
                    Text(s.$1,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: _blue,
                        )),
                    const SizedBox(height: 4),
                    Text(s.$2,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        )),
                  ],
                ))
            .toList(),
      ),
    );
  }

  // ── How it works ───────────────────────────────────────────────────────────
  Widget _buildHowItWorks() {
    final steps = [
      _Step(
          num: '01',
          icon: Icons.person_add_rounded,
          title: 'Создай профиль',
          desc:
              'Укажи навыки, университет и цели. Займёт 2 минуты.'),
      _Step(
          num: '02',
          icon: Icons.auto_awesome_rounded,
          title: 'AI подберёт стажировки',
          desc:
              'Получи персональный Match Score для каждой вакансии.'),
      _Step(
          num: '03',
          icon: Icons.send_rounded,
          title: 'Откликнись и подготовься',
          desc:
              'AI составит резюме и подготовит к собеседованию.'),
      _Step(
          num: '04',
          icon: Icons.workspace_premium_rounded,
          title: 'Получи стажировку',
          desc:
              'Начни карьеру в топовых компаниях Казахстана.'),
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      child: Column(
        children: [
          _SectionLabel('Как это работает'),
          const SizedBox(height: 8),
          Text(
            'Весь цикл стажировки на одной платформе',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 40),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: steps
                      .map((s) => Expanded(child: _StepCard(step: s)))
                      .toList(),
                );
              }
              return Column(
                children: steps
                    .map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _StepCard(step: s),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── For whom ───────────────────────────────────────────────────────────────
  Widget _buildForWhom(bool isDesktop) {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      child: Column(
        children: [
          _SectionLabel('Для кого'),
          const SizedBox(height: 8),
          Text(
            'Решение для каждого участника',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 40),
          LayoutBuilder(
            builder: (ctx, constraints) {
              final isWide = constraints.maxWidth > 700;
              final cards = [
                _ForWhomCard(
                  icon: Icons.school_rounded,
                  color: _blue,
                  title: 'Студентам',
                  points: [
                    'AI подбор стажировок по навыкам',
                    'Составление резюме и cover letter',
                    'Подготовка к собеседованию',
                    'Отслеживание откликов',
                  ],
                  cta: 'Найти стажировку',
                  onTap: _goToAuth,
                ),
                _ForWhomCard(
                  icon: Icons.business_rounded,
                  color: _purple,
                  title: 'Компаниям',
                  points: [
                    'Размещение вакансий за 5 минут',
                    'AI скоринг кандидатов',
                    'Управление откликами (Kanban)',
                    'Доступ к студентам топ-вузов',
                  ],
                  cta: 'Разместить вакансию',
                  onTap: _goToAuth,
                ),
                _ForWhomCard(
                  icon: Icons.account_balance_rounded,
                  color: _green,
                  title: 'Университетам',
                  points: [
                    'Мониторинг студентов в реальном времени',
                    'Отчёты для аккредитации',
                    'Аналитика трудоустройства',
                    'Уведомления о прогрессе',
                  ],
                  cta: 'Подключить вуз',
                  onTap: _goToAuth,
                  highlight: true,
                ),
              ];
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: cards
                      .map((c) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: c,
                            ),
                          ))
                      .toList(),
                );
              }
              return Column(
                children: cards
                    .map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: c,
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Testimonial ────────────────────────────────────────────────────────────
  Widget _buildTestimonial() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A8A), _blue],
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      child: Column(
        children: [
          const Icon(Icons.format_quote_rounded,
              color: Colors.white54, size: 48),
          const SizedBox(height: 16),
          const Text(
            '"Благодаря Qadam я нашла стажировку в Kaspi Bank за 2 недели. AI помог составить резюме и подготовиться к техническому собеседованию. Теперь я работаю full-time."',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              height: 1.7,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white24,
                child: const Text('АС',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Айгерим Сейтқали',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700)),
                  Text('iOS Developer @ Kaspi Bank',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 12)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Final CTA ──────────────────────────────────────────────────────────────
  Widget _buildFinalCta() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
      child: Column(
        children: [
          Text(
            'Начни карьеру сегодня',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Регистрация за 2 минуты. Бесплатно.',
            style: TextStyle(
                fontSize: 15,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _goToAuth,
            style: FilledButton.styleFrom(
              backgroundColor: _blue,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 40, vertical: 16),
            ),
            child: const Text(
              'Создать профиль →',
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Qadam',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  )),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Beta',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '© 2025 Qadam — Платформа стажировок в Казахстане',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────────────

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_blue, _purple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.trending_up_rounded,
              color: Colors.white, size: 18),
        ),
        const SizedBox(width: 8),
        const Text('Qadam',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            )),
      ],
    );
  }
}

class _NavLink extends StatelessWidget {
  final String label;
  const _NavLink(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(label,
          style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF374151),
              fontWeight: FontWeight.w500)),
    );
  }
}

class _HeroCta extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  const _HeroCta({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    if (primary) {
      return FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: _blue,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF374151),
        side: const BorderSide(color: Color(0xFFD1D5DB)),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: _blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: const TextStyle(
            color: _blue,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          )),
    );
  }
}

class _Step {
  final String num;
  final IconData icon;
  final String title;
  final String desc;

  const _Step(
      {required this.num,
      required this.icon,
      required this.title,
      required this.desc});
}

class _StepCard extends StatelessWidget {
  final _Step step;
  const _StepCard({required this.step});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(step.icon, color: _blue, size: 24),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: _blue,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Center(
                    child: Text(step.num,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(step.title,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A))),
          const SizedBox(height: 6),
          Text(step.desc,
              style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.5)),
        ],
      ),
    );
  }
}

class _ForWhomCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final List<String> points;
  final String cta;
  final VoidCallback onTap;
  final bool highlight;

  const _ForWhomCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.points,
    required this.cta,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: highlight ? color : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight ? color : const Color(0xFFE2E8F0),
        ),
        boxShadow: highlight
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.2),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                )
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                )
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: highlight
                  ? Colors.white.withValues(alpha: 0.2)
                  : color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                color: highlight ? Colors.white : color, size: 22),
          ),
          const SizedBox(height: 14),
          Text(title,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: highlight ? Colors.white : const Color(0xFF0F172A))),
          const SizedBox(height: 12),
          ...points.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        size: 16,
                        color: highlight ? Colors.white70 : color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(p,
                          style: TextStyle(
                              fontSize: 13,
                              color: highlight
                                  ? Colors.white.withValues(alpha: 0.9)
                                  : const Color(0xFF64748B),
                              height: 1.4)),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: highlight ? Colors.white : color,
                side: BorderSide(
                    color: highlight ? Colors.white54 : color.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(cta,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoJob {
  final String company;
  final String role;
  final String salary;
  final int match;
  final String tag;

  const _DemoJob({
    required this.company,
    required this.role,
    required this.salary,
    required this.match,
    required this.tag,
  });
}

class _DemoJobCard extends StatelessWidget {
  final _DemoJob job;
  const _DemoJobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final matchColor = job.match >= 85
        ? _green
        : job.match >= 70
            ? const Color(0xFFF59E0B)
            : const Color(0xFF6B7280);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                job.company.substring(0, 1),
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: _blue, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(job.role,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A))),
                const SizedBox(height: 2),
                Text('${job.company} · ${job.salary}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: matchColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${job.match}%',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: matchColor)),
          ),
        ],
      ),
    );
  }
}

