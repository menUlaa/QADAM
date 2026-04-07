import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:internship_app2/models/internship.dart';
import 'package:internship_app2/services/auth_service.dart';
import 'package:internship_app2/services/base_url.dart';
import 'package:internship_app2/services/cache_service.dart';

class OfflineException implements Exception {
  final List<Internship> cached;
  const OfflineException(this.cached);
}

/// Service for interacting with FastAPI backend
class ApiService {
  final AuthService _authService = AuthService();
  final CacheService _cache = CacheService();

  String get baseUrl => apiBaseUrl;

  /// Get headers with auth token if available
  Future<Map<String, String>> _getHeaders() async {
    final headers = {'Content-Type': 'application/json'};
    final token = await _authService.getToken();
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Fetch all internships. On network error, returns cached data.
  /// Throws [OfflineException] with cached list if offline but cache exists.
  Future<List<Internship>> getInternships() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/internships/'),
        headers: headers,
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        final internships = jsonList.map((j) => Internship.fromJson(j)).toList();
        await _cache.saveInternships(internships);
        return internships;
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      final cached = await _cache.loadInternships();
      if (cached != null && cached.isNotEmpty) {
        throw OfflineException(cached);
      }
      throw Exception('Network error: $e');
    }
  }

  /// Fetch single internship by ID
  Future<Internship> getInternship(int id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/internships/$id'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return Internship.fromJson(json);
      } else {
        throw Exception('Failed to load internship: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Submit application to an internship
  Future<void> apply(int internshipId, {String? message}) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/applications/'),
      headers: headers,
      body: json.encode({
        'internship_id': internshipId,
        if (message != null && message.isNotEmpty) 'message': message,
      }),
    );

    if (response.statusCode != 200) {
      final error = json.decode(response.body);
      throw Exception(error['detail'] ?? 'Failed to apply');
    }
  }

  /// Get current user's applications
  Future<List<Map<String, dynamic>>> getMyApplications() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/applications/my'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> list = json.decode(response.body);
      return list.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load applications');
    }
  }

  /// Get universities and specialties list
  Future<Map<String, dynamic>> getUniversities() async {
    final response = await http.get(Uri.parse('$baseUrl/auth/universities'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load universities');
  }

  /// Upload CV (PDF)
  Future<String> uploadCv(List<int> bytes, String fileName) async {
    final token = await _authService.getToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/auth/upload-cv'),
    );
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: fileName,
    ));
    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode == 200) {
      return json.decode(resp.body)['cv_url'] as String;
    }
    throw Exception(json.decode(resp.body)['detail'] ?? 'Upload failed');
  }

  /// AI chat
  Future<String> aiChat(List<Map<String, String>> messages) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/ai/chat'),
      headers: headers,
      body: json.encode({'messages': messages}),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body)['reply'] as String;
    }
    final err = json.decode(response.body);
    throw Exception(err['detail'] ?? 'AI error');
  }

  // ── Company methods ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> companyRegister(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/company/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode == 200) return json.decode(response.body);
    final err = json.decode(response.body);
    throw Exception(err['detail'] ?? 'Registration failed');
  }

  Future<Map<String, dynamic>> companyLogin(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/company/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    );
    if (response.statusCode == 200) return json.decode(response.body);
    final err = json.decode(response.body);
    throw Exception(err['detail'] ?? 'Login failed');
  }

  Future<List<Map<String, dynamic>>> getCompanyInternshipsList(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/company/internships'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List).cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to load');
  }

  Future<void> createCompanyInternship(String token, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/company/internships'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode != 200) {
      throw Exception(json.decode(response.body)['detail'] ?? 'Failed');
    }
  }

  Future<List<Map<String, dynamic>>> getCompanyApplications(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/company/applications'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      return (json.decode(response.body) as List).cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to load');
  }

  Future<void> updateApplicationStatus(String token, int appId, String status) async {
    final response = await http.put(
      Uri.parse('$baseUrl/company/applications/$appId/status'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: json.encode({'status': status}),
    );
    if (response.statusCode != 200) {
      throw Exception(json.decode(response.body)['detail'] ?? 'Failed');
    }
  }

  Future<Map<String, dynamic>> getCompanyStats(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/company/stats'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load stats');
  }

  /// Get list of companies
  Future<List<Map<String, dynamic>>> getCompanies() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/internships/companies/list'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final List<dynamic> list = json.decode(response.body);
      return list.cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to load companies');
  }

  /// Get internships by company name
  Future<List<Internship>> getCompanyInternships(String company) async {
    final headers = await _getHeaders();
    final encoded = Uri.encodeComponent(company);
    final response = await http.get(
      Uri.parse('$baseUrl/internships/companies/$encoded'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final List<dynamic> list = json.decode(response.body);
      return list.map((j) => Internship.fromJson(j)).toList();
    }
    throw Exception('Failed to load company internships');
  }

  /// Submit internship report for an accepted application
  Future<void> submitReport({
    required int applicationId,
    required int hoursCompleted,
    required String tasksDescription,
    required List<String> skillsGained,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/university/reports'),
      headers: headers,
      body: json.encode({
        'application_id': applicationId,
        'hours_completed': hoursCompleted,
        'tasks_description': tasksDescription,
        'skills_gained': skillsGained,
      }),
    );
    if (response.statusCode != 200) {
      final err = json.decode(response.body);
      throw Exception(err['detail'] ?? 'Failed to submit report');
    }
  }

  /// Test connection to backend
  Future<bool> testConnection() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
