import 'package:flutter/material.dart';
import 'package:internship_app2/models/internship.dart';
import 'package:internship_app2/screens/internship_detail_screen.dart';
import 'package:internship_app2/services/api_service.dart';
import 'package:internship_app2/services/favorites_service.dart';

class FavoritesScreen extends StatefulWidget {
  final VoidCallback? onGoToFeed;
  const FavoritesScreen({super.key, this.onGoToFeed});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _api = ApiService();
  final _favService = FavoritesService();

  List<Internship> _favorites = [];
  Set<int> _favoriteIds = {};
  bool _loading = true;
  bool _sortRecent = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.getInternships(),
        _favService.getAll(),
      ]);
      final all = results[0] as List<Internship>;
      final ids = results[1] as Set<int>;
      setState(() {
        _favoriteIds = ids;
        _favorites = all.where((i) => ids.contains(i.id)).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  List<Internship> get _sorted {
    final list = List<Internship>.of(_favorites);
    if (_sortRecent) {
      list.sort((a, b) => b.id.compareTo(a.id));
    } else {
      list.sort((a, b) => (b.salaryKzt ?? 0).compareTo(a.salaryKzt ?? 0));
    }
    return list;
  }

  Future<void> _removeFavorite(Internship intern) async {
    await _favService.toggle(intern.id);
    if (!mounted) return;
    setState(() {
      _favoriteIds.remove(intern.id);
      _favorites.removeWhere((i) => i.id == intern.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('«${intern.title}» удалено из избранного'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _openDetails(Internship it) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, _) => InternshipDetailScreen(internship: it),
        transitionsBuilder: (_, a, _, child) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
            child: child,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 260),
      ),
    );
  }

  static String _countLabel(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return '$n стажировка';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) {
      return '$n стажировки';
    }
    return '$n стажировок';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? _buildSkeleton()
              : _favorites.isEmpty
                  ? _buildEmptyOnly()
                  : _buildContent(),
        ),
      ),
    );
  }

  // ── Skeleton ─────────────────────────────────────────────────────────────────
  Widget _buildSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Row(children: [
            _skel(110, 22),
            const SizedBox(width: 8),
            _skel(80, 22, radius: 20),
            const Spacer(),
            _skel(76, 28, radius: 20),
            const SizedBox(width: 6),
            _skel(86, 28, radius: 20),
          ]),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _skel(double.infinity, 190)),
              const SizedBox(width: 12),
              Expanded(child: _skel(double.infinity, 205)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _skel(double.infinity, 195)),
              const SizedBox(width: 12),
              Expanded(child: _skel(double.infinity, 180)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _skel(double width, double height, {double radius = 8}) {
    return Container(
      width: width == double.infinity ? null : width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  // ── Empty-only state (no favorites) ─────────────────────────────────────────
  Widget _buildEmptyOnly() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.sizeOf(context).height - 100,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _EmptyCard(onGoToFeed: widget.onGoToFeed),
            ),
          ),
        ),
      ),
    );
  }

  // ── Full content ─────────────────────────────────────────────────────────────
  Widget _buildContent() {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // Header
        SliverToBoxAdapter(child: _buildHeader()),

        // 2-column grid
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cardW = (constraints.maxWidth - 12) / 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _sorted.map((it) => SizedBox(
                        width: cardW,
                        child: _FavCard(
                          internship: it,
                          onUnfavorite: () => _removeFavorite(it),
                          onTap: () => _openDetails(it),
                        ),
                      )).toList(),
                    );
                  },
                ),
              ),
            ),
          ),
        ),

        // Divider
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Divider(thickness: 0.5),
          ),
        ),

        // "That's all" card
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                child: _EmptyCard(onGoToFeed: widget.onGoToFeed),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
          child: Row(
            children: [
              const Text(
                'Избранное',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF4FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _countLabel(_favorites.length),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF0C447C),
                  ),
                ),
              ),
              const Spacer(),
              _SortPill(
                label: 'Недавние',
                active: _sortRecent,
                onTap: () => setState(() => _sortRecent = true),
              ),
              const SizedBox(width: 6),
              _SortPill(
                label: 'По зарплате',
                active: !_sortRecent,
                onTap: () => setState(() => _sortRecent = false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sort pill ─────────────────────────────────────────────────────────────────

class _SortPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SortPill({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFEFF4FF) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? const Color(0xFF85B7EB) : const Color(0xFFD1D5DB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: active ? const Color(0xFF0C447C) : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

// ── Company avatar ────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String name;

  static const _palette = [
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF06B6D4),
    Color(0xFF84CC16),
    Color(0xFFF97316),
  ];

  const _Avatar({required this.name});

  Color get _color => _palette[name.hashCode.abs() % _palette.length];

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts[0].length >= 2) return parts[0].substring(0, 2).toUpperCase();
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          _initials,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

// ── Tag pill ──────────────────────────────────────────────────────────────────

class _Tag extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const _Tag(
    this.label, {
    this.bg = const Color(0xFFF3F4F6),
    this.fg = const Color(0xFF6B7280),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: fg),
      ),
    );
  }
}

// ── Favorite card ─────────────────────────────────────────────────────────────

class _FavCard extends StatelessWidget {
  final Internship internship;
  final VoidCallback onUnfavorite;
  final VoidCallback onTap;

  const _FavCard({
    required this.internship,
    required this.onUnfavorite,
    required this.onTap,
  });

  static String _fmtDate(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  static String _fmtSalary(int kzt) {
    if (kzt >= 1000) {
      final k = kzt / 1000;
      return '${k == k.truncateToDouble() ? k.toInt() : k.toStringAsFixed(1)}K';
    }
    return kzt.toString();
  }

  @override
  Widget build(BuildContext context) {
    final it = internship;
    final dateStr = _fmtDate(it.createdAt);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row ────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Avatar(name: it.company),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        it.company,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2164F3),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 11,
                            color: Color(0xFF9CA3AF),
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              it.city,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onUnfavorite,
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(
                      Icons.bookmark_rounded,
                      size: 20,
                      color: Color(0xFF2164F3),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Title ──────────────────────────────────────────────────
            Text(
              it.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),

            // ── Tags ───────────────────────────────────────────────────
            Wrap(
              spacing: 5,
              runSpacing: 4,
              children: [
                if (it.format.isNotEmpty) _Tag(it.format),
                if (it.paid && it.salaryKzt != null)
                  _Tag(
                    '${_fmtSalary(it.salaryKzt!)} ₸',
                    bg: const Color(0xFFEAF3DE),
                    fg: const Color(0xFF27500A),
                  )
                else if (it.paid)
                  const _Tag(
                    'Оплачивается',
                    bg: Color(0xFFEAF3DE),
                    fg: Color(0xFF27500A),
                  ),
                if (it.duration.isNotEmpty) _Tag(it.duration),
              ],
            ),
            const SizedBox(height: 5),

            // ── Hashtags ───────────────────────────────────────────────
            if (it.tags.isNotEmpty)
              Text(
                it.tags.map((t) => '#$t').join(' '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
              ),

            const SizedBox(height: 8),
            const Divider(height: 1, thickness: 0.5, color: Color(0xFFE5E7EB)),
            const SizedBox(height: 8),

            // ── Footer ─────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: dateStr.isNotEmpty
                      ? Text(
                          dateStr,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9CA3AF),
                          ),
                          overflow: TextOverflow.ellipsis,
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF4FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Подать заявку',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2164F3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty / nudge card ────────────────────────────────────────────────────────

class _EmptyCard extends StatelessWidget {
  final VoidCallback? onGoToFeed;

  const _EmptyCard({this.onGoToFeed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF4FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.bookmarks_outlined,
              size: 28,
              color: Color(0xFF2164F3),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Это всё избранное пока что',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Сохраняй стажировки которые тебя заинтересовали и возвращайся к ним в любое время',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF9CA3AF),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          if (onGoToFeed != null)
            SizedBox(
              height: 40,
              child: ElevatedButton(
                onPressed: onGoToFeed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2164F3),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
                child: const Text(
                  'Найти стажировки',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
