import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService {
  static const _key = 'favorite_ids';

  Future<Set<int>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    return list.map(int.parse).toSet();
  }

  Future<bool> toggle(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    final set = list.map(int.parse).toSet();
    final added = !set.contains(id);
    added ? set.add(id) : set.remove(id);
    await prefs.setStringList(_key, set.map((e) => e.toString()).toList());
    return added;
  }
}
