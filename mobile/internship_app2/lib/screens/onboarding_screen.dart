import 'package:flutter/material.dart';
import 'package:internship_app2/l10n/strings.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

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

  void _next() {
    if (_page < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    } else {
      widget.onDone();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages.length - 1;
    final cfg = _pages[_page];

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: cfg.colors,
          ),
        ),
        child: Stack(
          children: [
            // ── Decorative background circles ──────────────────────────
            Positioned(
              top: -60,
              right: -40,
              child: _bgCircle(220, 0.05),
            ),
            Positioned(
              top: 80,
              right: -70,
              child: _bgCircle(150, 0.07),
            ),
            Positioned(
              bottom: 120,
              left: -60,
              child: _bgCircle(200, 0.05),
            ),
            Positioned(
              bottom: -30,
              right: 40,
              child: _bgCircle(100, 0.06),
            ),

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
                      itemCount: _pages.length,
                      itemBuilder: (_, i) =>
                          _OnboardingPage(config: _pages[i]),
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
                          children: List.generate(_pages.length, (i) {
                            final active = i == _page;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 4),
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
                          child: isLast
                              ? FilledButton(
                                  onPressed: _next,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: cfg.colors.last,
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
                                      color:
                                          Colors.white.withValues(alpha: 0.5),
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

// ── Page widget ───────────────────────────────────────────────────────────────

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
