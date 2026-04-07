import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:internship_app2/services/base_url.dart';

class UniversityInfo {
  final int id;
  final String name;
  final String email;
  final String city;

  const UniversityInfo({
    required this.id,
    required this.name,
    required this.email,
    required this.city,
  });

  factory UniversityInfo.fromJson(Map<String, dynamic> j) => UniversityInfo(
        id: j['id'],
        name: j['name'],
        email: j['email'],
        city: j['city'] ?? '',
      );
}

class StudentApplication {
  final int id;
  final String internshipTitle;
  final String company;
  final String status;
  final String createdAt;
  final bool hasReport;

  const StudentApplication({
    required this.id,
    required this.internshipTitle,
    required this.company,
    required this.status,
    required this.createdAt,
    required this.hasReport,
  });

  factory StudentApplication.fromJson(Map<String, dynamic> j) =>
      StudentApplication(
        id: j['id'],
        internshipTitle: j['internship_title'],
        company: j['company'],
        status: j['status'],
        createdAt: j['created_at'],
        hasReport: j['has_report'] ?? false,
      );
}

class StudentRecord {
  final int userId;
  final String name;
  final String email;
  final String specialty;
  final int? studyYear;
  final String studentIdNumber;
  final List<StudentApplication> applications;

  const StudentRecord({
    required this.userId,
    required this.name,
    required this.email,
    required this.specialty,
    required this.studyYear,
    required this.studentIdNumber,
    required this.applications,
  });

  factory StudentRecord.fromJson(Map<String, dynamic> j) => StudentRecord(
        userId: j['user_id'],
        name: j['name'],
        email: j['email'],
        specialty: j['specialty'] ?? '',
        studyYear: j['study_year'],
        studentIdNumber: j['student_id_number'] ?? '',
        applications: (j['applications'] as List)
            .map((a) => StudentApplication.fromJson(a))
            .toList(),
      );

  int get totalApps => applications.length;
  int get accepted => applications.where((a) => a.status == 'accepted').length;
  int get pending => applications.where((a) => a.status == 'pending').length;
}

class UniversityAnalytics {
  final int totalStudents;
  final int totalApplications;
  final int accepted;
  final int rejected;
  final int pending;
  final double acceptanceRate;
  final List<Map<String, dynamic>> byCategory;
  final List<Map<String, dynamic>> topCompanies;

  const UniversityAnalytics({
    required this.totalStudents,
    required this.totalApplications,
    required this.accepted,
    required this.rejected,
    required this.pending,
    required this.acceptanceRate,
    required this.byCategory,
    required this.topCompanies,
  });

  factory UniversityAnalytics.fromJson(Map<String, dynamic> j) =>
      UniversityAnalytics(
        totalStudents: j['total_students'],
        totalApplications: j['total_applications'],
        accepted: j['accepted'],
        rejected: j['rejected'],
        pending: j['pending'],
        acceptanceRate: (j['acceptance_rate'] as num).toDouble(),
        byCategory: List<Map<String, dynamic>>.from(j['by_category']),
        topCompanies: List<Map<String, dynamic>>.from(j['top_companies']),
      );
}

class UniversityService {
  static const _tokenKey = 'university_token';
  static const _infoKey = 'university_info';

  String get _base => apiBaseUrl;

  Map<String, String> _headers([String? token]) {
    final h = {'Content-Type': 'application/json'};
    if (token != null) h['Authorization'] = 'Bearer $token';
    return h;
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<UniversityInfo?> getSavedInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_infoKey);
    if (raw == null) return null;
    return UniversityInfo.fromJson(jsonDecode(raw));
  }

  Future<void> _saveSession(String token, Map<String, dynamic> info) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_infoKey, jsonEncode(info));
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_infoKey);
  }

  Future<UniversityInfo> register({
    required String name,
    required String email,
    required String password,
    required String city,
  }) async {
    final res = await http.post(
      Uri.parse('$_base/university/register'),
      headers: _headers(),
      body: jsonEncode({'name': name, 'email': email, 'password': password, 'city': city}),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode != 200) {
      throw Exception(body['detail'] ?? 'Registration failed');
    }
    await _saveSession(body['access_token'], body['university']);
    return UniversityInfo.fromJson(body['university']);
  }

  Future<UniversityInfo> login({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$_base/university/login'),
      headers: _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode != 200) {
      throw Exception(body['detail'] ?? 'Login failed');
    }
    await _saveSession(body['access_token'], body['university']);
    return UniversityInfo.fromJson(body['university']);
  }

  Future<List<StudentRecord>> getStudents() async {
    final token = await getToken();
    final res = await http.get(
      Uri.parse('$_base/university/students'),
      headers: _headers(token),
    );
    if (res.statusCode != 200) throw Exception('Failed to load students');
    final list = jsonDecode(res.body) as List;
    return list.map((j) => StudentRecord.fromJson(j)).toList();
  }

  Future<UniversityAnalytics> getAnalytics() async {
    final token = await getToken();
    final res = await http.get(
      Uri.parse('$_base/university/analytics'),
      headers: _headers(token),
    );
    if (res.statusCode != 200) throw Exception('Failed to load analytics');
    return UniversityAnalytics.fromJson(jsonDecode(res.body));
  }

  Future<void> linkStudent({
    required String studentEmail,
    String specialty = '',
    int? studyYear,
    String studentIdNumber = '',
  }) async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('$_base/university/students/link'),
      headers: _headers(token),
      body: jsonEncode({
        'student_email': studentEmail,
        'specialty': specialty,
        'study_year': studyYear,
        'student_id_number': studentIdNumber,
      }),
    );
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body);
      throw Exception(body['detail'] ?? 'Failed to link student');
    }
  }

  Future<void> unlinkStudent(int userId) async {
    final token = await getToken();
    final res = await http.delete(
      Uri.parse('$_base/university/students/$userId'),
      headers: _headers(token),
    );
    if (res.statusCode != 200) throw Exception('Failed to unlink student');
  }
}
