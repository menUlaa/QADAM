import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:internship_app2/models/internship.dart';

class CacheService {
  static const _internshipsKey = 'cached_internships';
  static const _cachedAtKey = 'cached_internships_at';

  Future<void> saveInternships(List<Internship> internships) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(internships.map((i) => i.toJson()).toList());
    await prefs.setString(_internshipsKey, jsonStr);
    await prefs.setInt(_cachedAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<List<Internship>?> loadInternships() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_internshipsKey);
    if (jsonStr == null) return null;
    final list = jsonDecode(jsonStr) as List;
    return list
        .map((j) => Internship.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Returns how old the cache is, or null if no cache.
  Future<Duration?> cacheAge() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_cachedAtKey);
    if (ms == null) return null;
    return DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
  }
}
