import 'package:flutter/material.dart';
import 'package:internship_app2/l10n/strings.dart';
import 'package:internship_app2/screens/ai_chat_screen.dart';
import 'package:internship_app2/screens/companies_screen.dart';
import 'package:internship_app2/screens/favorites_screen.dart';
import 'package:internship_app2/screens/feed_screen.dart';
import 'package:internship_app2/screens/profile_screen.dart';

class MainScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const MainScreen({super.key, required this.onLogout});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width > 720;

    final screens = [
      FeedScreen(),
      FavoritesScreen(),
      const CompaniesScreen(),
      const AiChatScreen(),
      ProfileScreen(onLogout: widget.onLogout),
    ];

    if (isDesktop) {
      return Scaffold(
        backgroundColor: const Color(0xFFF3F2EF),
        body: Column(
          children: [
            _DesktopHeader(
              currentIndex: _currentIndex,
              onTabSelected: (i) => setState(() => _currentIndex = i),
            ),
            Expanded(child: screens[_currentIndex]),
          ],
        ),
      );
    }

    // ── Mobile layout ──────────────────────────────────────────────────────
    return Scaffold(
      body: Stack(
        children: List.generate(screens.length, (i) => AnimatedOpacity(
          opacity: _currentIndex == i ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 180),
          child: IgnorePointer(
            ignoring: _currentIndex != i,
            child: screens[i],
          ),
        )),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        indicatorColor: const Color(0xFFEBF0FA),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.search_outlined),
            selectedIcon: const Icon(Icons.search, color: Color(0xFF2164F3)),
            label: tr('nav_feed'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.bookmark_outline_rounded),
            selectedIcon: const Icon(Icons.bookmark_rounded, color: Color(0xFF2164F3)),
            label: tr('nav_favorites'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.business_outlined),
            selectedIcon: const Icon(Icons.business, color: Color(0xFF2164F3)),
            label: tr('nav_companies'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.auto_awesome_outlined),
            selectedIcon: const Icon(Icons.auto_awesome, color: Color(0xFF2164F3)),
            label: 'AI',
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person, color: Color(0xFF2164F3)),
            label: tr('nav_profile'),
          ),
        ],
      ),
    );
  }
}

// ── Desktop white top navbar ───────────────────────────────────────────────────

class _DesktopHeader extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTabSelected;

  const _DesktopHeader({
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE4E2E0))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 40),
      height: 62,
      child: Row(
        children: [
          // Logo
          const Text(
            'Qadam',
            style: TextStyle(
              color: Color(0xFF2164F3),
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(width: 40),

          // Nav tabs
          _NavTab(
            label: tr('nav_feed'),
            icon: Icons.search_rounded,
            selected: currentIndex == 0,
            onTap: () => onTabSelected(0),
          ),
          _NavTab(
            label: tr('nav_favorites'),
            icon: Icons.bookmark_outline_rounded,
            selected: currentIndex == 1,
            onTap: () => onTabSelected(1),
          ),
          _NavTab(
            label: tr('nav_companies'),
            icon: Icons.business_outlined,
            selected: currentIndex == 2,
            onTap: () => onTabSelected(2),
          ),
          _NavTab(
            label: 'AI Ассистент',
            icon: Icons.auto_awesome_outlined,
            selected: currentIndex == 3,
            onTap: () => onTabSelected(3),
          ),
          _NavTab(
            label: tr('nav_profile'),
            icon: Icons.person_outline_rounded,
            selected: currentIndex == 4,
            onTap: () => onTabSelected(4),
          ),

          const Spacer(),

          // Language switcher
          ValueListenableBuilder<String>(
            valueListenable: localeNotifier,
            builder: (_, lang, w) => Row(
              children: [
                for (final e in {'RU': 'ru', 'ҚЗ': 'kz', 'EN': 'en'}.entries)
                  GestureDetector(
                    onTap: () => setLocale(e.value),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 5),
                      decoration: BoxDecoration(
                        color: lang == e.value
                            ? const Color(0xFFEBF0FA)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: lang == e.value
                              ? const Color(0xFF2164F3)
                              : const Color(0xFFD1D5DB),
                        ),
                      ),
                      child: Text(
                        e.key,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: lang == e.value
                              ? const Color(0xFF2164F3)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _NavTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      hoverColor: const Color(0xFFF5F5F5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: selected
            ? const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFF2164F3), width: 2),
                ),
              )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 17,
              color: selected ? const Color(0xFF2164F3) : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? const Color(0xFF2164F3)
                    : const Color(0xFF374151),
                fontSize: 14,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
