import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:internship_app2/services/api_service.dart';
import 'package:internship_app2/models/internship.dart';

// ── Interest categories ────────────────────────────────────────────────────────

const _interestCategories = [
  _Interest('IT',         Icons.code_rounded,                Color(0xFF2164F3), 'IT'),
  _Interest('Дизайн',     Icons.palette_outlined,            Color(0xFF8B5CF6), 'Дизайн'),
  _Interest('Финансы',    Icons.account_balance_outlined,    Color(0xFF10B981), 'Финансы'),
  _Interest('Маркетинг',  Icons.campaign_outlined,           Color(0xFFF59E0B), 'Маркетинг'),
  _Interest('HR',         Icons.people_outlined,             Color(0xFFEF4444), 'HR'),
  _Interest('Другое',     Icons.lightbulb_outline_rounded,   Color(0xFF6B7280), 'Другое'),
];

class _Interest {
  final String label;
  final IconData icon;
  final Color color;
  final String categoryKey;
  const _Interest(this.label, this.icon, this.color, this.categoryKey);
}

// ── Screen ────────────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _controller = PageController();
  final _api = ApiService();
  int _page = 0;

  final Set<String> _selectedInterests = {};

  List<Internship> _ahaInternships = [];
  bool _ahaLoading = false;
  late AnimationController _counterAnim;
  late Animation<double> _counterValue;

  List<String> _allSkills = [];
  final Set<String> _selectedSkills = {};
  bool _skillsLoading = true;

  static const _fallbackSkills = [
    'Python', 'JavaScript', 'Flutter', 'Dart', 'Java', 'Kotlin',
    'React', 'Vue.js', 'Node.js', 'SQL', 'PostgreSQL', 'Docker',
    'Git', 'Figma', 'Excel', 'Power BI', 'Machine Learning',
    'Data Analysis', 'Marketing', 'SMM', 'Copywriting',
    'Project Management', 'AutoCAD', 'Photoshop',
  ];

  static const _totalPages = 4;

  @override
  void initState() {
    super.initState();
    _counterAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _counterValue = const AlwaysStoppedAnimation(0);
    _loadSkills();
  }

  @override
  void dispose() {
    _controller.dispose();
    _counterAnim.dispose();
    super.dispose();
  }

  Future<void> _loadSkills() async {
    try {
      final skills = await _api.getSkills();
      if (mounted) {
        setState(() {
          _allSkills = skills.map((s) => s['name'] as String).toList();
          _skillsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _allSkills = _fallbackSkills; _skillsLoading = false; });
    }
  }

  Future<void> _fetchAha() async {
    setState(() => _ahaLoading = true);
    try {
      final all = await _api.getInternships();
      final keys = _interestCategories
          .where((i) => _selectedInterests.contains(i.label))
          .map((i) => i.categoryKey)
          .toSet();
      final filtered = keys.isEmpty ? all : all.where((i) => keys.contains(i.category)).toList();
      if (mounted) {
        setState(() { _ahaInternships = filtered; _ahaLoading = false; });
        _counterValue = Tween<double>(begin: 0, end: filtered.length.toDouble())
            .animate(CurvedAnimation(parent: _counterAnim, curve: Curves.easeOut));
        _counterAnim.forward(from: 0);
      }
    } catch (_) {
      if (mounted) setState(() => _ahaLoading = false);
    }
  }

  void _next() {
    if (_page == 1) _fetchAha();
    if (_page < _totalPages - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    if (_selectedSkills.isNotEmpty) {
      await prefs.setStringList('pending_skills', _selectedSkills.toList());
    }
    if (_selectedInterests.isNotEmpty) {
      final keys = _interestCategories
          .where((i) => _selectedInterests.contains(i.label))
          .map((i) => i.categoryKey)
          .toList();
      await prefs.setStringList('preferred_categories', keys);
    }
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ── Top bar ──────────────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Step dots
                  Row(
                    children: List.generate(_totalPages, (i) {
                      final active = i == _page;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 6),
                        width: active ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: active ? const Color(0xFF2164F3) : const Color(0xFFD1D5DB),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                  TextButton(
                    onPressed: widget.onDone,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF6B7280),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    child: const Text('Пропустить',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),

          // ── Pages ────────────────────────────────────────────────────────
          Expanded(
            child: PageView(
              controller: _controller,
              onPageChanged: (i) => setState(() => _page = i),
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _WelcomePage(),
                _InterestsPage(
                  selected: _selectedInterests,
                  onToggle: (l) => setState(() =>
                      _selectedInterests.contains(l)
                          ? _selectedInterests.remove(l)
                          : _selectedInterests.add(l)),
                ),
                _AhaPage(
                  internships: _ahaInternships,
                  loading: _ahaLoading,
                  counterValue: _counterValue,
                  counterAnim: _counterAnim,
                  selectedInterests: _selectedInterests,
                ),
                _SkillsPage(
                  allSkills: _allSkills,
                  selected: _selectedSkills,
                  loading: _skillsLoading,
                  onToggle: (s) => setState(() =>
                      _selectedSkills.contains(s)
                          ? _selectedSkills.remove(s)
                          : _selectedSkills.add(s)),
                ),
              ],
            ),
          ),

          // ── Bottom button ─────────────────────────────────────────────
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _next,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2164F3),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _page == _totalPages - 1 ? 'Начать поиск' :
                            _page == 1 && _selectedInterests.isNotEmpty ? 'Показать стажировки' :
                            'Далее',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _page == _totalPages - 1 ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_page == 3) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: widget.onDone,
                      child: const Text(
                        'Пропустить, добавлю позже',
                        style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Page 0: Welcome ───────────────────────────────────────────────────────────

class _WelcomePage extends StatefulWidget {
  @override
  State<_WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<_WelcomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _anim.forward();
  }

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 32),
              // Hero illustration
              Container(
                width: double.infinity,
                height: 220,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1A3FAA), Color(0xFF2164F3)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Stack(
                  children: [
                    // Decorative circles
                    Positioned(top: -30, right: -30,
                        child: _circle(140, Colors.white.withValues(alpha: 0.06))),
                    Positioned(bottom: -20, left: -20,
                        child: _circle(100, Colors.white.withValues(alpha: 0.06))),
                    // Content
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 72, height: 72,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.rocket_launch_rounded, size: 38, color: Colors.white),
                          ),
                          const SizedBox(height: 16),
                          const Text('Qadam',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1,
                              )),
                          const SizedBox(height: 4),
                          Text('Твой шаг к карьере',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),
              const Text(
                'Стажировки\nпо всему Казахстану',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                  height: 1.15,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Найди стажировку, подай заявку и отслеживай\nстатус — всё в одном приложении.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF6B7280),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 32),
              // Feature pills
              Wrap(
                spacing: 8, runSpacing: 8,
                alignment: WrapAlignment.center,
                children: const [
                  _Pill('🔍  Умный поиск'),
                  _Pill('🤖  AI-помощник'),
                  _Pill('📬  Статус заявок'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circle(double size, Color color) => Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color));
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDDE7FF)),
      ),
      child: Text(text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2164F3))),
    );
  }
}

// ── Page 1: Interests picker ──────────────────────────────────────────────────

class _InterestsPage extends StatelessWidget {
  final Set<String> selected;
  final void Function(String) onToggle;
  const _InterestsPage({required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text('Что тебя\nинтересует?',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
                height: 1.15,
                letterSpacing: -0.5,
              )),
          const SizedBox(height: 6),
          const Text('Выбери направления — подберём стажировки',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.5)),
          const SizedBox(height: 20),
          // 3-column grid — all 6 fit in 2 rows, no scrolling needed
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.15,
            children: _interestCategories.map((interest) {
              final isSelected = selected.contains(interest.label);
              return GestureDetector(
                onTap: () => onToggle(interest.label),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? interest.color.withValues(alpha: 0.08)
                        : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? interest.color : const Color(0xFFE5E7EB),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected ? [
                      BoxShadow(color: interest.color.withValues(alpha: 0.15),
                          blurRadius: 8, offset: const Offset(0, 2)),
                    ] : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(interest.icon, size: 26, color: interest.color),
                      const SizedBox(height: 6),
                      Text(
                        interest.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? interest.color : const Color(0xFF374151),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          if (selected.isNotEmpty)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF2164F3)),
                  const SizedBox(width: 8),
                  Text(
                    'Выбрано: ${selected.join(', ')}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2164F3)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Page 2: AHA moment ────────────────────────────────────────────────────────

class _AhaPage extends StatelessWidget {
  final List<Internship> internships;
  final bool loading;
  final Animation<double> counterValue;
  final AnimationController counterAnim;
  final Set<String> selectedInterests;

  const _AhaPage({
    required this.internships,
    required this.loading,
    required this.counterValue,
    required this.counterAnim,
    required this.selectedInterests,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF2164F3), strokeWidth: 3),
            SizedBox(height: 20),
            Text('Ищем стажировки для тебя...',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          // Counter card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A3FAA), Color(0xFF2164F3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedInterests.isEmpty ? 'Все направления' : selectedInterests.join(' · '),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedBuilder(
                  animation: counterValue,
                  builder: (_, _) {
                    final n = counterValue.value.toInt();
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('$n',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 56,
                              fontWeight: FontWeight.w900,
                              height: 1,
                              letterSpacing: -2,
                            )),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8, left: 4),
                          child: Text('стажировок',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              )),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 4),
                const Text('ждут тебя прямо сейчас!',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Несколько вариантов',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
          const SizedBox(height: 12),
          Expanded(
            child: internships.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search_off_rounded, size: 48, color: Color(0xFFD1D5DB)),
                        const SizedBox(height: 12),
                        Text('Стажировок пока нет\nпо выбранным направлениям',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: const Color(0xFF6B7280), fontSize: 14)),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: internships.take(4).length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _InternshipPreviewCard(internship: internships[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _InternshipPreviewCard extends StatelessWidget {
  final Internship internship;
  const _InternshipPreviewCard({required this.internship});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.work_outline_rounded, color: Color(0xFF2164F3), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(internship.title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(internship.company,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (internship.paid)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Оплата',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
                ),
              const SizedBox(height: 2),
              Text(internship.city,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Page 3: Skills picker ─────────────────────────────────────────────────────

class _SkillsPage extends StatelessWidget {
  final List<String> allSkills;
  final Set<String> selected;
  final bool loading;
  final void Function(String) onToggle;

  const _SkillsPage({
    required this.allSkills,
    required this.selected,
    required this.loading,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text('Твои навыки',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
                height: 1.15,
                letterSpacing: -0.5,
              )),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('Необязательно — ',
                  style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
              const Text('можно добавить позже',
                  style: TextStyle(fontSize: 14, color: Color(0xFF2164F3), fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 14),
          if (selected.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Выбрано ${selected.length}: чем больше — тем точнее подбор',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2164F3)),
              ),
            ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2164F3)))
                : SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: allSkills.map((skill) {
                        final isSelected = selected.contains(skill);
                        return GestureDetector(
                          onTap: () => onToggle(skill),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF2164F3) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF2164F3) : const Color(0xFFE5E7EB),
                              ),
                              boxShadow: isSelected ? const [
                                BoxShadow(color: Color(0x302164F3), blurRadius: 6, offset: Offset(0, 2)),
                              ] : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSelected) ...[
                                  const Icon(Icons.check_rounded, size: 13, color: Colors.white),
                                  const SizedBox(width: 4),
                                ],
                                Text(skill,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? Colors.white : const Color(0xFF374151),
                                    )),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
