import 'package:flutter/material.dart';
import 'package:internship_app2/l10n/strings.dart';
import 'package:internship_app2/models/internship.dart';
import 'package:internship_app2/screens/details_screen.dart';
import 'package:internship_app2/services/api_service.dart';
import 'package:internship_app2/services/favorites_service.dart';
import 'package:internship_app2/widgets/internship_card.dart';
import 'package:internship_app2/widgets/skeleton_card.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _api = ApiService();
  final _favService = FavoritesService();

  List<Internship> _favorites = [];
  Set<int> _favoriteIds = {};
  bool _loading = true;

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

  Future<void> _toggleFavorite(int id) async {
    final added = await _favService.toggle(id);
    setState(() {
      if (added) {
        _favoriteIds.add(id);
      } else {
        _favoriteIds.remove(id);
        _favorites.removeWhere((i) => i.id == id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('favorites_title'), style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: tr('refresh'),
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 5,
                itemBuilder: (_, _) => const SkeletonCard(),
              )
            : _favorites.isEmpty
                ? _EmptyFavorites()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _favorites.length,
                    itemBuilder: (context, i) {
                      final it = _favorites[i];
                      return InternshipCard(
                        internship: it,
                        isFavorite: _favoriteIds.contains(it.id),
                        onFavoriteToggle: () => _toggleFavorite(it.id),
                        onTap: () => Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (_, animation, _) =>
                                DetailsScreen(internship: it),
                            transitionsBuilder: (_, animation, _, child) =>
                                FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.04),
                                  end: Offset.zero,
                                ).animate(CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.easeOut)),
                                child: child,
                              ),
                            ),
                            transitionDuration:
                                const Duration(milliseconds: 260),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0F2166), Color(0xFF2164F3)],
                    ),
                  ),
                ),
                const Icon(
                  Icons.bookmark_outline_rounded,
                  size: 54,
                  color: Colors.white,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              tr('no_favorites'),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              tr('no_favorites_sub'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF9CA3AF),
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
