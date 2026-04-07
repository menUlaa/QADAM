import 'package:flutter/material.dart';
import 'package:internship_app2/l10n/strings.dart';
import 'package:internship_app2/models/internship.dart';
import 'package:internship_app2/screens/details_screen.dart';
import 'package:internship_app2/services/api_service.dart';
import 'package:internship_app2/services/favorites_service.dart';
import 'package:internship_app2/widgets/internship_card.dart';

// ── Company color map ─────────────────────────────────────────────────────────

const _companyColors = {
  'Kaspi Bank': Color(0xFFE63946),
  'Halyk Bank': Color(0xFF2A9D8F),
  'Kolesa Group': Color(0xFF2164F3),
  'Jusan Bank': Color(0xFF7C3AED),
  'EPAM Systems Kazakhstan': Color(0xFF0F766E),
  'Chocofamily': Color(0xFFB45309),
  'Wildberries Казахстан': Color(0xFF6D28D9),
  'Beeline Казахстан': Color(0xFFD97706),
};

Color _colorForCompany(String name) {
  return _companyColors[name] ?? const Color(0xFF2164F3);
}

// ── Companies list screen ─────────────────────────────────────────────────────

class CompaniesScreen extends StatefulWidget {
  const CompaniesScreen({super.key});

  @override
  State<CompaniesScreen> createState() => _CompaniesScreenState();
}

class _CompaniesScreenState extends State<CompaniesScreen> {
  final _api = ApiService();
  final _search = TextEditingController();

  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search.addListener(_filter);
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final companies = await _api.getCompanies();
      setState(() {
        _all = companies;
        _filtered = companies;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _filter() {
    final q = _search.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _all
          : _all
              .where((c) =>
                  (c['name'] as String).toLowerCase().contains(q) ||
                  (c['categories'] as List).any(
                      (cat) => cat.toString().toLowerCase().contains(q)))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width > 720;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: isDesktop
          ? null
          : AppBar(
              title: Text(tr('nav_companies')),
            ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(
                isDesktop ? 40 : 16, 12, isDesktop ? 40 : 16, 12),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: tr('companies_search_hint'),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF2164F3)),
                suffixIcon: _search.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => _search.clear(),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xFF2164F3), width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          Expanded(
            child: _loading
                ? GridView.builder(
                    padding: EdgeInsets.all(isDesktop ? 32 : 16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isDesktop ? 3 : 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: isDesktop ? 1.6 : 1.2,
                    ),
                    itemCount: 6,
                    itemBuilder: (_, i) => const _SkeletonCompanyCard(),
                  )
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 48, color: Colors.red),
                            const SizedBox(height: 12),
                            Text(_error!,
                                textAlign: TextAlign.center,
                                style:
                                    const TextStyle(color: Color(0xFF6B7280))),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _load,
                              icon: const Icon(Icons.refresh),
                              label: Text(tr('retry')),
                            ),
                          ],
                        ),
                      )
                    : _filtered.isEmpty
                        ? Center(
                            child: Text(tr('no_results'),
                                style: const TextStyle(
                                    color: Color(0xFF6B7280), fontSize: 15)))
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: GridView.builder(
                              padding: EdgeInsets.all(isDesktop ? 32 : 16),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: isDesktop ? 3 : 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: isDesktop ? 1.6 : 1.2,
                              ),
                              itemCount: _filtered.length,
                              itemBuilder: (context, i) =>
                                  _CompanyCard(company: _filtered[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonCompanyCard extends StatefulWidget {
  const _SkeletonCompanyCard();

  @override
  State<_SkeletonCompanyCard> createState() => _SkeletonCompanyCardState();
}

class _SkeletonCompanyCardState extends State<_SkeletonCompanyCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, w) {
        final opacity = 0.06 + _anim.value * 0.08;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _box(44, 44, radius: 12, opacity: opacity),
                  const Spacer(),
                  _box(24, 36, radius: 8, opacity: opacity),
                ],
              ),
              const SizedBox(height: 10),
              _box(14, double.infinity, opacity: opacity),
              const SizedBox(height: 6),
              _box(12, 100, opacity: opacity),
              const Spacer(),
              _box(11, 80, opacity: opacity),
            ],
          ),
        );
      },
    );
  }

  Widget _box(double height, double width,
      {double radius = 8, required double opacity}) =>
      Container(
        height: height,
        width: width == double.infinity ? null : width,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: opacity),
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

class _CompanyCard extends StatelessWidget {
  final Map<String, dynamic> company;
  const _CompanyCard({required this.company});

  @override
  Widget build(BuildContext context) {
    final name = company['name'] as String;
    final count = company['internship_count'] as int;
    final categories = (company['categories'] as List).cast<String>();
    final cities = (company['cities'] as List).cast<String>();
    final color = _colorForCompany(name);

    final initials = name
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0])
        .take(2)
        .join()
        .toUpperCase();

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (ctx, a1, a2) => CompanyDetailScreen(company: name),
          transitionsBuilder: (ctx, animation, a2, child) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 220),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 12,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top gradient strip
              Container(
                height: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.5)],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar + count
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                initials,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: color,
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Company name
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      // City
                      if (cities.isNotEmpty)
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 12, color: Color(0xFF9CA3AF)),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                cities.take(2).join(', '),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF9CA3AF),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      if (categories.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          categories.take(2).join(' · '),
                          style: TextStyle(
                            fontSize: 11,
                            color: color.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Company detail screen ─────────────────────────────────────────────────────

class CompanyDetailScreen extends StatefulWidget {
  final String company;
  const CompanyDetailScreen({super.key, required this.company});

  @override
  State<CompanyDetailScreen> createState() => _CompanyDetailScreenState();
}

class _CompanyDetailScreenState extends State<CompanyDetailScreen> {
  final _api = ApiService();
  final _favService = FavoritesService();

  List<Internship> _internships = [];
  Set<int> _favoriteIds = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _api.getCompanyInternships(widget.company),
      _favService.getAll(),
    ]);
    if (mounted) {
      setState(() {
        _internships = results[0] as List<Internship>;
        _favoriteIds = results[1] as Set<int>;
        _loading = false;
      });
    }
  }

  Future<void> _toggleFavorite(int id) async {
    final added = await _favService.toggle(id);
    setState(() => added ? _favoriteIds.add(id) : _favoriteIds.remove(id));
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForCompany(widget.company);
    final isDesktop = MediaQuery.sizeOf(context).width > 720;

    final initials = widget.company
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0])
        .take(2)
        .join()
        .toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: color,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withValues(alpha: 0.9),
                      color,
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Decorative circles
                    Positioned(
                      top: -20,
                      right: -20,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 10,
                      right: 60,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.07),
                        ),
                      ),
                    ),
                    // Content
                    Positioned(
                      bottom: 24,
                      left: isDesktop ? 40 : 20,
                      right: 20,
                      child: Row(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3)),
                            ),
                            child: Center(
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.company,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (!_loading)
                                  Text(
                                    '${_internships.length} ${tr('stat_vacancies')}',
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.75),
                                      fontSize: 13,
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
            ),
          ),

          // Internships
          if (_loading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF2164F3)),
              ),
            )
          else if (_internships.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text(tr('no_results'),
                    style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 15)),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.all(isDesktop ? 24 : 16),
              sliver: isDesktop
                  ? SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 0,
                        childAspectRatio: 2.4,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => InternshipCard(
                          internship: _internships[index],
                          isFavorite:
                              _favoriteIds.contains(_internships[index].id),
                          onFavoriteToggle: () =>
                              _toggleFavorite(_internships[index].id),
                          onTagTap: (_) {},
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DetailsScreen(
                                  internship: _internships[index]),
                            ),
                          ),
                        ),
                        childCount: _internships.length,
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => InternshipCard(
                          internship: _internships[index],
                          isFavorite:
                              _favoriteIds.contains(_internships[index].id),
                          onFavoriteToggle: () =>
                              _toggleFavorite(_internships[index].id),
                          onTagTap: (_) {},
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DetailsScreen(
                                  internship: _internships[index]),
                            ),
                          ),
                        ),
                        childCount: _internships.length,
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}
