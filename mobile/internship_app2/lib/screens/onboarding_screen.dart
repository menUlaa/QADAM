import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:internship_app2/l10n/strings.dart';
import 'package:internship_app2/services/api_service.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  final _api = ApiService();
  int _page = 0;

  // Skills page state
  List<String> _allSkills = [];
  final Set<String> _selected = {};
  bool _skillsLoading = true;

  // Predefined popular skills as fallback / initial display
  static const _fallbackSkills = [
    'Python', 'JavaScript', 'Flutter', 'Dart', 'Java', 'Kotlin',
    'Swift', 'React', 'Vue.js', 'Node.js', 'SQL', 'PostgreSQL',
    'MongoDB', 'Docker', 'Git', 'Figma', 'Photoshop', 'Excel',
    'Power BI', 'Machine Learning', 'Data Analysis', 'Marketing',
    'SMM', 'Copywriting', 'Project Management', 'AutoCAD',
  ];

  static const _pages = [
    _PageConfig(
      colors: [Color(0xFF0F2166), Color(0xFF2164F3)],
      icon: Icons.search_rounded,
      titleKey: 'ob1_title',
      subtitleKey: 'ob1_sub',
    ),
    _PageConfig(
      colors: [Color(0xFF064E3B), Color(0xFF059669)],
      icon: Icons.send_rounded,
      titleKey: 'ob2_title',
      subtitleKey: 'ob2_sub',
    ),
    _PageConfig(
      colors: [Color(0xFF312E81), Color(0xFF6D28D9)],
      icon: Icons.check_circle_outline_rounded,
      titleKey: 'ob3_title',
      subtitleKey: 'ob3_sub',
    ),
  ];

  // Total pages = info pages + skills page
  int get _totalPages => _pages.length + 1;
  bool get _isSkillsPage => _page == _pages.length;
  bool get _isLast => _page == _totalPages - 1;

  @override
  void initState() {
    super.initState();
    _loadSkills();
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
      if (mounted) {
        setState(() {
          _allSkills = _fallbackSkills;
          _skillsLoading = false;
        });
      }
    }
  }

  void _next() {
    if (_page < _totalPages - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    // Save selected skills to SharedPreferences for later use after login
    if (_selected.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('pending_skills', _selected.toList());
    }
    widget.onDone();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _isSkillsPage ? null : _pages[_page];
    final colors = cfg?.colors ?? [const Color(0xFF1E1B4B), const Color(0xFF4C1D95)];

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
        child: Stack(
          children: [
            // ── Decorative background circles ──────────────────────────
            Positioned(top: -60, right: -40, child: _bgCircle(220, 0.05)),
            Positioned(top: 80, right: -70, child: _bgCircle(150, 0.07)),
            Positioned(bottom: 120, left: -60, child: _bgCircle(200, 0.05)),
            Positioned(bottom: -30, right: 40, child: _bgCircle(100, 0.06)),

            // ── Content ────────────────────────────────────────────────
            SafeArea(
              child: Column(
                children: [
                  // Skip button
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 8, 16, 0),
                      child: TextButton(
                        onPressed: widget.onDone,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                        ),
                        child: Text(
                          tr('skip'),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Pages
                  Expanded(
                    child: PageView.builder(
                      controller: _controller,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemCount: _totalPages,
                      itemBuilder: (_, i) {
                        if (i < _pages.length) {
                          return _OnboardingPage(config: _pages[i]);
                        }
                        return _SkillsPage(
                          allSkills: _allSkills,
                          selected: _selected,
                          loading: _skillsLoading,
                          onToggle: (skill) =>
                              setState(() => _selected.contains(skill)
                                  ? _selected.remove(skill)
                                  : _selected.add(skill)),
                        );
                      },
                    ),
                  ),

                  // ── Bottom controls ──────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 44),
                    child: Column(
                      children: [
                        // Dots
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_totalPages, (i) {
                            final active = i == _page;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: active ? 22 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: active
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 28),

                        // Button
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: _isLast
                              ? FilledButton(
                                  onPressed: _finish,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: colors.last,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Text(
                                    tr('start'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                )
                              : OutlinedButton(
                                  onPressed: _next,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(
                                      color: Colors.white.withValues(alpha: 0.5),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        tr('next'),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                ),
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
    );
  }

  Widget _bgCircle(double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
        ),
      );
}

// ── Skills selection page ─────────────────────────────────────────────────────

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
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text(
            'Твои навыки',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              height: 1.12,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Выбери навыки, которыми владеешь — мы подберём подходящие стажировки',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          if (loading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: allSkills.map((skill) {
                    final isSelected = selected.contains(skill);
                    return GestureDetector(
                      onTap: () => onToggle(skill),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected) ...[
                              Icon(
                                Icons.check_rounded,
                                size: 14,
                                color: const Color(0xFF4C1D95),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              skill,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? const Color(0xFF4C1D95)
                                    : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          if (selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                'Выбрано: ${selected.length}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Page config ───────────────────────────────────────────────────────────────

class _PageConfig {
  final List<Color> colors;
  final IconData icon;
  final String titleKey;
  final String subtitleKey;

  const _PageConfig({
    required this.colors,
    required this.icon,
    required this.titleKey,
    required this.subtitleKey,
  });
}

// ── Info page widget ──────────────────────────────────────────────────────────

class _OnboardingPage extends StatelessWidget {
  final _PageConfig config;
  const _OnboardingPage({required this.config});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Concentric circles illustration
          SizedBox(
            width: 240,
            height: 240,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                  child: Icon(
                    config.icon,
                    size: 56,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          Text(
            tr(config.titleKey),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              height: 1.12,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            tr(config.subtitleKey),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
