import 'package:flutter/material.dart';
import 'package:internship_app2/l10n/strings.dart';
import 'package:internship_app2/models/internship.dart';
import 'package:internship_app2/screens/internship_detail_screen.dart';
import 'package:internship_app2/services/api_service.dart';
import 'package:internship_app2/services/favorites_service.dart';
import 'package:internship_app2/widgets/desktop_footer.dart';
import 'package:internship_app2/widgets/empty_state.dart';
import 'package:internship_app2/widgets/filter_sheet.dart';
import 'package:internship_app2/widgets/internship_card.dart';
import 'package:internship_app2/widgets/skeleton_card.dart';
import 'package:url_launcher/url_launcher.dart';

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
    setState(() { isLoading = true; error = null; _isOffline = false; });
    try {
      final results = await Future.wait([
        _apiService.getInternships(),
        _apiService.fetchExternalVacancies(),
      ]);
      final internal = results[0];
      final external = results[1];
      final merged = [...internal, ...external];
      merged.sort((a, b) {
        final aDate = a.createdAt;
        final bDate = b.createdAt;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });
      setState(() { all = merged; isLoading = false; });
      _applyFilters();
    } on OfflineException catch (e) {
      // Offline: show cached internal vacancies only
      setState(() { all = e.cached; isLoading = false; _isOffline = true; });
      _applyFilters();
    } catch (e) {
      setState(() { error = e.toString(); isLoading = false; });
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

    if (_filters.salaryMin != null) {
      result.removeWhere((it) => (it.salaryKzt ?? 0) < _filters.salaryMin!);
    }
    if (_filters.salaryMax != null) {
      result.removeWhere((it) => (it.salaryKzt ?? 0) > _filters.salaryMax!);
    }

    switch (_filters.sort) {
      case SortOption.salaryDesc:
        result.sort((a, b) => (b.salaryKzt ?? 0).compareTo(a.salaryKzt ?? 0));
      case SortOption.salaryAsc:
        result.sort((a, b) => (a.salaryKzt ?? 0).compareTo(b.salaryKzt ?? 0));
      case SortOption.dateSort:
        result.sort((a, b) => b.id.compareTo(a.id));
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
        color: const Color(0xFFF3F2EF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.search, color: Color(0xFF767676), size: 20),
          ),
          Expanded(
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: tr('search_hint'),
                hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_search.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, size: 16, color: Color(0xFF9CA3AF)),
              onPressed: () => _search.clear(),
            ),
        ],
      ),
    );
  }

  Widget _filterButton(int activeFilters) {
    return GestureDetector(
      onTap: _openFilters,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: activeFilters > 0 ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: activeFilters > 0
                ? const Color(0xFF2164F3)
                : const Color(0xFFD1D5DB),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune_rounded,
                size: 16,
                color: activeFilters > 0
                    ? const Color(0xFF2164F3)
                    : const Color(0xFF595959)),
            const SizedBox(width: 5),
            Text(
              activeFilters > 0 ? 'Фильтры ($activeFilters)' : 'Фильтры',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: activeFilters > 0
                    ? const Color(0xFF2164F3)
                    : const Color(0xFF595959),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width > 720;
    final activeFilters = _filters.activeCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F2EF),
      appBar: isDesktop ? null : AppBar(
              toolbarHeight: 0,
              elevation: 0,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              bottom: PreferredSize(
                preferredSize: Size.zero,
                child: Divider(height: 1, color: Colors.grey.shade200),
              ),
            ),
      body: Column(
        children: [
          // Mobile-only search + header
          if (!isDesktop)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top: title + filter button
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Qadam',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF2557A7),
                                  letterSpacing: -0.5,
                                )),
                            Text(
                              'Стажировки в Казахстане',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                      _filterButton(activeFilters),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Search bar
                  _searchBox(),
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
              InternshipDetailScreen(internship: it),
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

class _DesktopFilterSidebar extends StatefulWidget {
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
  State<_DesktopFilterSidebar> createState() => _DesktopFilterSidebarState();
}

class _DesktopFilterSidebarState extends State<_DesktopFilterSidebar> {
  static const _blue = Color(0xFF2164F3);
  static const _divColor = Color(0xFFE5E7EB);

  // Section open/closed
  bool _s1 = true, _s2 = true, _s3 = true, _s4 = true, _s5 = false;

  // Filter state
  late SortOption _sort;
  late bool _paidOnly;
  late RangeValues _salaryRange;
  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();
  late Set<String> _formats;
  late Set<String> _cities;
  final _citySearch = TextEditingController();
  bool _showAllCities = false;

  static const double _salaryMax = 500000;

  @override
  void initState() {
    super.initState();
    _syncFromWidget();
  }

  @override
  void didUpdateWidget(_DesktopFilterSidebar old) {
    super.didUpdateWidget(old);
    if (widget.current != old.current) _syncFromWidget();
  }

  void _syncFromWidget() {
    _sort = widget.current.sort;
    _paidOnly = widget.current.paidOnly;
    final lo = widget.current.salaryMin ?? 0;
    final hi = widget.current.salaryMax ?? _salaryMax;
    _salaryRange = RangeValues(lo, hi);
    _minCtrl.text = lo > 0 ? lo.toInt().toString() : '';
    _maxCtrl.text = hi < _salaryMax ? hi.toInt().toString() : '';
    _formats = Set.of(widget.current.formats);
    _cities = Set.of(widget.current.cities);
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    _citySearch.dispose();
    super.dispose();
  }

  void _apply() {
    widget.onChanged(FilterOptions(
      sort: _sort,
      paidOnly: _paidOnly,
      formats: Set.of(_formats),
      cities: Set.of(_cities),
      salaryMin: _paidOnly && _salaryRange.start > 0 ? _salaryRange.start : null,
      salaryMax: _paidOnly && _salaryRange.end < _salaryMax ? _salaryRange.end : null,
    ));
  }

  void _reset() {
    setState(() {
      _sort = SortOption.defaultSort;
      _paidOnly = false;
      _salaryRange = const RangeValues(0, _salaryMax);
      _minCtrl.clear();
      _maxCtrl.clear();
      _formats.clear();
      _cities.clear();
      _citySearch.clear();
    });
    widget.onChanged(const FilterOptions());
  }

  bool get _isDirty => _sort != SortOption.defaultSort ||
      _paidOnly ||
      _formats.isNotEmpty ||
      _cities.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: _divColor)),
      ),
      child: Column(
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
            child: Row(
              children: [
                const Text(
                  'Фильтры',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                ),
                const Spacer(),
                if (_isDirty)
                  GestureDetector(
                    onTap: _reset,
                    child: const Text(
                      'Сбросить',
                      style: TextStyle(fontSize: 12, color: _blue, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: _divColor),

          // ── Scrollable sections ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                _Section(
                  title: tr('filter_sort'),
                  open: _s1,
                  onToggle: () => setState(() => _s1 = !_s1),
                  child: Column(
                    children: SortOption.values.map((opt) {
                      final sel = _sort == opt;
                      return InkWell(
                        onTap: () { setState(() => _sort = opt); _apply(); },
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: Radio<SortOption>(
                                  value: opt,
                                  groupValue: _sort,
                                  activeColor: _blue,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  onChanged: (v) { setState(() => _sort = v!); _apply(); },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                sortLabel(opt),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                                  color: sel ? _blue : const Color(0xFF374151),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                _Section(
                  title: tr('filter_pay'),
                  open: _s2,
                  onToggle: () => setState(() => _s2 = !_s2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Switch(
                            value: _paidOnly,
                            activeColor: _blue,
                            onChanged: (v) { setState(() => _paidOnly = v); _apply(); },
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              tr('paid_only'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: _paidOnly ? _blue : const Color(0xFF374151),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_paidOnly) ...[
                        const SizedBox(height: 8),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                            activeTrackColor: _blue,
                            thumbColor: _blue,
                            inactiveTrackColor: const Color(0xFFE5E7EB),
                          ),
                          child: RangeSlider(
                            values: _salaryRange,
                            min: 0,
                            max: _salaryMax,
                            divisions: 50,
                            onChanged: (v) {
                              setState(() {
                                _salaryRange = v;
                                _minCtrl.text = v.start > 0 ? v.start.toInt().toString() : '';
                                _maxCtrl.text = v.end < _salaryMax ? v.end.toInt().toString() : '';
                              });
                            },
                            onChangeEnd: (_) => _apply(),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _SalaryField(
                                controller: _minCtrl,
                                hint: 'от',
                                onSubmit: (v) {
                                  final n = double.tryParse(v);
                                  if (n != null) {
                                    setState(() => _salaryRange = RangeValues(n.clamp(0, _salaryRange.end), _salaryRange.end));
                                    _apply();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _SalaryField(
                                controller: _maxCtrl,
                                hint: 'до',
                                onSubmit: (v) {
                                  final n = double.tryParse(v);
                                  if (n != null) {
                                    setState(() => _salaryRange = RangeValues(_salaryRange.start, n.clamp(_salaryRange.start, _salaryMax)));
                                    _apply();
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                _Section(
                  title: tr('filter_format'),
                  open: _s3,
                  onToggle: () => setState(() => _s3 = !_s3),
                  child: Column(
                    children: [
                      ('Office', 'On-site'),
                      ('Remote', 'Remote'),
                      ('Hybrid', 'Hybrid'),
                    ].map((entry) {
                      final (value, label) = entry;
                      final sel = _formats.contains(value);
                      return InkWell(
                        onTap: () {
                          setState(() => sel ? _formats.remove(value) : _formats.add(value));
                          _apply();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: sel ? const Color(0xFF2164F3) : Colors.white,
                                  border: Border.all(
                                    color: sel ? const Color(0xFF2164F3) : const Color(0xFFD1D5DB),
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: sel
                                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Text(label,
                                  style: const TextStyle(
                                      fontSize: 13, color: Color(0xFF374151))),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                if (widget.availableCities.isNotEmpty)
                  _Section(
                    title: tr('filter_city'),
                    open: _s4,
                    onToggle: () => setState(() => _s4 = !_s4),
                    child: Column(
                      children: [
                        if (widget.availableCities.length > 5)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: TextField(
                              controller: _citySearch,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: 'Поиск города',
                                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                                prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF9CA3AF)),
                                filled: true,
                                fillColor: const Color(0xFFF3F4F6),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ...() {
                          final q = _citySearch.text.toLowerCase();
                          final visible = widget.availableCities
                              .where((c) => c.toLowerCase().contains(q))
                              .toList();
                          final shown = _showAllCities ? visible : visible.take(5).toList();
                          return [
                            ...shown.map((c) {
                              final sel = _cities.contains(c);
                              return CheckboxListTile(
                                dense: true,
                                value: sel,
                                activeColor: _blue,
                                contentPadding: EdgeInsets.zero,
                                controlAffinity: ListTileControlAffinity.leading,
                                title: Text(c, style: const TextStyle(fontSize: 13, color: Color(0xFF374151))),
                                onChanged: (v) {
                                  setState(() { v! ? _cities.add(c) : _cities.remove(c); });
                                  _apply();
                                },
                              );
                            }),
                            if (visible.length > 5)
                              GestureDetector(
                                onTap: () => setState(() => _showAllCities = !_showAllCities),
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    _showAllCities
                                        ? 'Скрыть'
                                        : 'Показать ещё ${visible.length - 5}',
                                    style: const TextStyle(fontSize: 12, color: _blue, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                          ];
                        }(),
                      ],
                    ),
                  ),

                // Active filter chips summary
                if (_isDirty) ...[
                  const SizedBox(height: 4),
                  const Divider(height: 1, color: _divColor),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (_sort != SortOption.defaultSort)
                          _ActiveChip(label: sortLabel(_sort), onRemove: () { setState(() => _sort = SortOption.defaultSort); _apply(); }),
                        if (_paidOnly)
                          _ActiveChip(label: tr('paid_only'), onRemove: () { setState(() => _paidOnly = false); _apply(); }),
                        ..._formats.map((f) => _ActiveChip(label: f, onRemove: () { setState(() => _formats.remove(f)); _apply(); })),
                        ..._cities.map((c) => _ActiveChip(label: c, onRemove: () { setState(() => _cities.remove(c)); _apply(); })),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final bool open;
  final VoidCallback onToggle;
  final Widget child;

  const _Section({
    required this.title,
    required this.open,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF374151),
                    letterSpacing: 0.4,
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: open ? 0 : -0.25,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.expand_more_rounded, size: 18, color: Color(0xFF9CA3AF)),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: child,
          ),
          secondChild: const SizedBox.shrink(),
          crossFadeState: open ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 200),
        ),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
      ],
    );
  }
}

class _SalaryField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final void Function(String) onSubmit;

  const _SalaryField({
    required this.controller,
    required this.hint,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      onSubmitted: onSubmit,
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        suffixText: '₸',
        suffixStyle: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
      ),
      style: const TextStyle(fontSize: 13),
    );
  }
}

class _ActiveChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _ActiveChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEBF0FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2164F3)),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded, size: 12, color: Color(0xFF2164F3)),
          ),
        ],
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
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: _categoryKeys.length,
              separatorBuilder: (_, _) => const SizedBox(width: 4),
              itemBuilder: (context, i) {
                final cat = _categoryKeys[i];
                final isSelected = cat == selected;
                return GestureDetector(
                  onTap: () => onSelect(cat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isSelected
                              ? const Color(0xFF2557A7)
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _categoryIcons[cat] ?? Icons.label_outline,
                          size: 14,
                          color: isSelected
                              ? const Color(0xFF2557A7)
                              : const Color(0xFF767676),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          tr(cat),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? const Color(0xFF2557A7)
                                : const Color(0xFF595959),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE4E2E0)),
        ],
      ),
    );
  }
}
