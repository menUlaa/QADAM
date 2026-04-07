import 'package:flutter/material.dart';
import 'package:internship_app2/l10n/strings.dart';
import 'package:internship_app2/models/internship.dart';
import 'package:internship_app2/screens/details_screen.dart';
import 'package:internship_app2/services/api_service.dart';
import 'package:internship_app2/services/favorites_service.dart';
import 'package:internship_app2/widgets/desktop_footer.dart';
import 'package:internship_app2/widgets/empty_state.dart';
import 'package:internship_app2/widgets/filter_sheet.dart';
import 'package:internship_app2/widgets/internship_card.dart';
import 'package:internship_app2/widgets/skeleton_card.dart';

// tr() keys — used as internal identifiers for selected state
const _categoryKeys = [
  'cat_all',
  'cat_it',
  'cat_finance',
  'cat_design',
  'cat_marketing',
  'cat_hr',
];

// Maps tr key → backend category value (Russian, as stored in DB)
const _categoryBackend = {
  'cat_it': 'IT',
  'cat_finance': 'Финансы',
  'cat_design': 'Дизайн',
  'cat_marketing': 'Маркетинг',
  'cat_hr': 'HR',
};

const _categoryIcons = {
  'cat_all': Icons.apps_rounded,
  'cat_it': Icons.code_rounded,
  'cat_finance': Icons.account_balance_rounded,
  'cat_design': Icons.brush_rounded,
  'cat_marketing': Icons.campaign_rounded,
  'cat_hr': Icons.people_rounded,
};

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _search = TextEditingController();
  final _apiService = ApiService();
  final _favService = FavoritesService();

  String _selectedCategory = 'cat_all';
  String? _selectedTag;
  FilterOptions _filters = const FilterOptions();
  bool isLoading = true;
  String? error;
  bool _isOffline = false;
  int _displayLimit = 20;

  List<Internship> all = [];
  List<Internship> filtered = [];
  Set<int> _favoriteIds = {};

  @override
  void initState() {
    super.initState();
    _search.addListener(_applyFilters);
    _loadInternships();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final ids = await _favService.getAll();
    if (mounted) setState(() => _favoriteIds = ids);
  }

  Future<void> _toggleFavorite(int id) async {
    final added = await _favService.toggle(id);
    setState(() => added ? _favoriteIds.add(id) : _favoriteIds.remove(id));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadInternships() async {
    setState(() {
      isLoading = true;
      error = null;
      _isOffline = false;
    });
    try {
      final internships = await _apiService.getInternships();
      setState(() {
        all = internships;
        isLoading = false;
      });
      _applyFilters();
    } on OfflineException catch (e) {
      setState(() {
        all = e.cached;
        isLoading = false;
        _isOffline = true;
      });
      _applyFilters();
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  void _applyFilters() {
    final q = _search.text.trim().toLowerCase();
    final result = all.where((it) {
      if (_filters.paidOnly && !it.paid) return false;
      if (_filters.formats.isNotEmpty && !_filters.formats.contains(it.format)) return false;
      if (_filters.cities.isNotEmpty && !_filters.cities.contains(it.city)) return false;
      if (_selectedCategory != 'cat_all') {
        final backendVal = _categoryBackend[_selectedCategory] ?? _selectedCategory;
        if (it.category != backendVal) return false;
      }
      if (_selectedTag != null && !it.tags.contains(_selectedTag)) return false;
      if (q.isEmpty) return true;
      return it.title.toLowerCase().contains(q) ||
          it.company.toLowerCase().contains(q) ||
          it.city.toLowerCase().contains(q) ||
          it.tags.join(' ').toLowerCase().contains(q);
    }).toList();

    switch (_filters.sort) {
      case SortOption.salaryDesc:
        result.sort((a, b) => (b.salaryKzt ?? 0).compareTo(a.salaryKzt ?? 0));
      case SortOption.salaryAsc:
        result.sort((a, b) => (a.salaryKzt ?? 0).compareTo(b.salaryKzt ?? 0));
      case SortOption.defaultSort:
        break;
    }

    setState(() {
      filtered = result;
      _displayLimit = 20;
    });
  }

  void _selectCategory(String cat) {
    setState(() => _selectedCategory = cat);
    _applyFilters();
  }

  void _filterByTag(String tag) {
    setState(() => _selectedTag = tag);
    _applyFilters();
  }

  void _clearTag() {
    setState(() => _selectedTag = null);
    _applyFilters();
  }

  void _openFilters() {
    final cities = all.map((e) => e.city).toSet().where((c) => c.isNotEmpty).toList()..sort();
    final formats = all.map((e) => e.format).toSet().toList()..sort();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: FilterSheet(
          current: _filters,
          availableCities: cities,
          availableFormats: formats,
          onApply: (f) {
            setState(() => _filters = f);
            _applyFilters();
          },
        ),
      ),
    );
  }

  Widget _heroIconBtn({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _searchBox() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.search, color: Color(0xFF2164F3), size: 22),
          ),
          Expanded(
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: tr('search_hint'),
                hintStyle: const TextStyle(
                    color: Color(0xFF767676), fontSize: 15),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
          if (_search.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close,
                  size: 18, color: Color(0xFF767676)),
              onPressed: () => _search.clear(),
            ),
        ],
      ),
    );
  }

  Widget _filterButton(int activeFilters) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ElevatedButton.icon(
          onPressed: _openFilters,
          icon: const Icon(Icons.tune_rounded, size: 18),
          label: Text(tr('filters_title')),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF2164F3),
            elevation: 2,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6)),
          ),
        ),
        if (activeFilters > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                  color: Colors.orange, shape: BoxShape.circle),
              child: Center(
                child: Text(
                  '$activeFilters',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width > 720;
    final activeFilters = _filters.activeCount;

    return Scaffold(
      // On desktop the header is in MainScreen, so no AppBar here
      appBar: isDesktop
          ? null
          : AppBar(
              title: const Text('Qadam'),
              actions: [
                IconButton(
                  tooltip: tr('refresh'),
                  onPressed: _loadInternships,
                  icon: const Icon(Icons.refresh),
                ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      tooltip: tr('filters_title'),
                      onPressed: _openFilters,
                      icon: const Icon(Icons.tune_rounded),
                    ),
                    if (activeFilters > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '$activeFilters',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 6),
              ],
            ),
      body: Column(
        children: [
          // Mobile-only search bar (desktop hero is inside the scroll view)
          if (!isDesktop)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0F2166), Color(0xFF2164F3)],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              child: Row(
                children: [
                  Expanded(child: _searchBox()),
                  const SizedBox(width: 8),
                  _filterButton(activeFilters),
                ],
              ),
            ),

          // ── Offline banner ────────────────────────────────────────────
          if (_isOffline)
            Material(
              color: const Color(0xFFFFF7ED),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off_rounded,
                        size: 16, color: Color(0xFFEA580C)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tr('offline_banner'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFEA580C),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _loadInternships,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        tr('refresh'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFEA580C),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadInternships,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Internship it) {
    return InternshipCard(
      internship: it,
      isFavorite: _favoriteIds.contains(it.id),
      onFavoriteToggle: () => _toggleFavorite(it.id),
      onTagTap: _filterByTag,
      onTap: () => Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, animation, _) =>
              DetailsScreen(internship: it),
          transitionsBuilder: (_, animation, _, child) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                  parent: animation, curve: Curves.easeOut)),
              child: child,
            ),
          ),
          transitionDuration: const Duration(milliseconds: 260),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final isDesktop = MediaQuery.sizeOf(context).width > 720;

    if (isLoading) {
      final list = ListView.builder(
        padding: EdgeInsets.all(isDesktop ? 24 : 16),
        itemCount: 5,
        itemBuilder: (_, _) => const SkeletonCard(),
      );
      if (!isDesktop) return list;
      return _desktopRow(list);
    }

    if (error != null) {
      final errWidget = Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(tr('error_load'), style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(error!, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadInternships,
                icon: const Icon(Icons.refresh),
                label: Text(tr('retry')),
              ),
            ],
          ),
        ),
      );
      if (!isDesktop) return errWidget;
      return _desktopRow(errWidget);
    }

    final feed = CustomScrollView(
      slivers: [

        // Desktop hero — scrolls with content
        if (isDesktop)
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0F2166), Color(0xFF2164F3)],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(40, 52, 40, 44),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF34D399), shape: BoxShape.circle)),
                            const SizedBox(width: 7),
                            Text(tr('app_tagline'), style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(tr('hero_title'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900, height: 1.12, letterSpacing: -1.5)),
                      const SizedBox(height: 14),
                      Text(tr('hero_sub'), textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 16, height: 1.6)),
                      const SizedBox(height: 30),
                      Row(
                        children: [
                          Expanded(child: _searchBox()),
                          const SizedBox(width: 10),
                          _heroIconBtn(icon: Icons.refresh_rounded, onPressed: _loadInternships, tooltip: tr('refresh')),
                        ],
                      ),
                      if (all.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _StatBadge(value: '${all.length}+', label: tr('stat_vacancies'), icon: Icons.work_outline_rounded),
                            const SizedBox(width: 10),
                            _StatBadge(value: '${all.map((e) => e.company).toSet().length}+', label: tr('stat_companies'), icon: Icons.business_rounded),
                            const SizedBox(width: 10),
                            _StatBadge(value: '${all.map((e) => e.city).toSet().where((c) => c.isNotEmpty).length}+', label: tr('stat_cities'), icon: Icons.location_city_rounded),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

        SliverToBoxAdapter(
          child: _CategoryBar(
            selected: _selectedCategory,
            onSelect: _selectCategory,
          ),
        ),
        // Active tag chip
        if (_selectedTag != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Row(
                children: [
                  FilterChip(
                    avatar: const Icon(Icons.tag, size: 14),
                    label: Text('#$_selectedTag'),
                    selected: true,
                    onSelected: (_) => _clearTag(),
                    visualDensity: VisualDensity.compact,
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: _clearTag,
                  ),
                ],
              ),
            ),
          ),
        if (filtered.isEmpty)
          SliverFillRemaining(
            child: EmptyState(
              title: tr('no_results'),
              subtitle: tr('no_results_sub'),
              onClear: () {
                _search.clear();
                setState(() {
                  _filters = const FilterOptions();
                  _selectedCategory = 'cat_all';
                  _selectedTag = null;
                });
                _applyFilters();
              },
            ),
          )
        else ...[
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
                isDesktop ? 24 : 16, 8, isDesktop ? 24 : 16, 0),
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
                      (context, index) =>
                          _buildCard(filtered[index]),
                      childCount:
                          _displayLimit.clamp(0, filtered.length),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _buildCard(filtered[index]),
                      childCount:
                          _displayLimit.clamp(0, filtered.length),
                    ),
                  ),
          ),
          // Load more button
          if (_displayLimit < filtered.length)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    isDesktop ? 24 : 16, 8, isDesktop ? 24 : 16, 8),
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _displayLimit += 20),
                  icon: const Icon(Icons.expand_more),
                  label: Text(tr('load_more')),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),

          // Footer — always at the very bottom, fades in when reached
          SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              children: [
                const Spacer(),
                if (isDesktop) const DesktopFooter(),
              ],
            ),
          ),
        ],
      ],
    );

    if (!isDesktop) return feed;
    return _desktopRow(feed);
  }

  Widget _desktopRow(Widget content) {
    final cities = all.map((e) => e.city).toSet().where((c) => c.isNotEmpty).toList()..sort();
    final formats = all.map((e) => e.format).toSet().toList()..sort();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 260,
          child: _DesktopFilterSidebar(
            current: _filters,
            availableCities: cities,
            availableFormats: formats,
            onChanged: (f) {
              setState(() => _filters = f);
              _applyFilters();
            },
          ),
        ),
        Expanded(child: content),
      ],
    );
  }
}

class _DesktopFilterSidebar extends StatelessWidget {
  final FilterOptions current;
  final List<String> availableCities;
  final List<String> availableFormats;
  final void Function(FilterOptions) onChanged;

  const _DesktopFilterSidebar({
    required this.current,
    required this.availableCities,
    required this.availableFormats,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
        children: [
          // Header
          Row(
            children: [
              const Text(
                'Фильтры',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
              ),
              const Spacer(),
              if (!current.isEmpty)
                GestureDetector(
                  onTap: () => onChanged(const FilterOptions()),
                  child: Text(
                    tr('reset'),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF2164F3), fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Sort
          _sectionHeader(tr('filter_sort')),
          const SizedBox(height: 8),
          ...SortOption.values.map((opt) {
            final selected = current.sort == opt;
            return GestureDetector(
              onTap: () => onChanged(current.copyWith(sort: opt)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFEBF0FA) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        sortLabel(opt),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? const Color(0xFF2164F3) : const Color(0xFF374151),
                        ),
                      ),
                    ),
                    if (selected)
                      const Icon(Icons.check_rounded, size: 16, color: Color(0xFF2164F3)),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),

          // Paid only
          _sectionHeader(tr('filter_pay')),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => onChanged(current.copyWith(paidOnly: !current.paidOnly)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: current.paidOnly
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: current.paidOnly ? const Color(0xFF16A34A) : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.attach_money_rounded,
                      size: 16,
                      color: current.paidOnly ? const Color(0xFF16A34A) : const Color(0xFF9CA3AF)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr('paid_only'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: current.paidOnly ? const Color(0xFF16A34A) : const Color(0xFF374151),
                      ),
                    ),
                  ),
                  if (current.paidOnly)
                    const Icon(Icons.check_rounded, size: 16, color: Color(0xFF16A34A)),
                ],
              ),
            ),
          ),

          if (availableFormats.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionHeader(tr('filter_format')),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: availableFormats.map((f) {
                final sel = current.formats.contains(f);
                return _chip(
                  label: f,
                  selected: sel,
                  onTap: () {
                    final updated = Set<String>.of(current.formats);
                    sel ? updated.remove(f) : updated.add(f);
                    onChanged(current.copyWith(formats: updated));
                  },
                );
              }).toList(),
            ),
          ],

          if (availableCities.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionHeader(tr('filter_city')),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: availableCities.map((c) {
                final sel = current.cities.contains(c);
                return _chip(
                  label: c,
                  selected: sel,
                  onTap: () {
                    final updated = Set<String>.of(current.cities);
                    sel ? updated.remove(c) : updated.add(c);
                    onChanged(current.copyWith(cities: updated));
                  },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: const Color(0xFF2164F3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B7280),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2164F3) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _StatBadge({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.8)),
          const SizedBox(width: 7),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  final String selected;
  final void Function(String) onSelect;

  const _CategoryBar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _categoryKeys.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat = _categoryKeys[i];
          final isSelected = cat == selected;
          return GestureDetector(
            onTap: () => onSelect(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? cs.primary : cs.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? cs.primary : cs.outlineVariant,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _categoryIcons[cat] ?? Icons.label_outline,
                    size: 15,
                    color: isSelected ? Colors.white : cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    tr(cat),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
