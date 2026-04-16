import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:internship_app2/models/user.dart';
import 'package:internship_app2/services/base_url.dart';

// ── Google Sign-In configuration ──────────────────────────────────────────────
// Get your client ID from https://console.cloud.google.com/
// Create OAuth 2.0 credentials → Web application
// Add your ngrok/production URL to "Authorized JavaScript origins"
const _kGoogleClientId =
    'YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com'; // <── replace this

final _googleSignIn = GoogleSignIn(
  clientId: _kGoogleClientId,
  scopes: ['email', 'profile'],
);

/// Service for authentication and token management
class AuthService {
  String get baseUrl => apiBaseUrl;
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  /// Register new user — returns RegisterResult (may require email verification)
  Future<RegisterResult> register({
    required String email,
    required String firstName,
    required String lastName,
    required String password,
    required String confirmPassword,
    bool isGraduate = false,
    String? universityName,
    String? specialty,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'password': password,
        'confirm_password': confirmPassword,
        'is_graduate': isGraduate,
        if (universityName != null && universityName.isNotEmpty)
          'university_name': universityName,
        if (specialty != null && specialty.isNotEmpty)
          'specialty': specialty,
      }),
    ).timeout(
      const Duration(seconds: 60),
      onTimeout: () => throw Exception(
        'Сервер просыпается — подождите и попробуйте снова',
      ),
    );

    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      if (body.containsKey('access_token')) {
        final authResponse = AuthResponse.fromJson(body);
        await _saveAuth(authResponse);
        return RegisterResult(requiresVerification: false);
      }
      return RegisterResult(requiresVerification: true);
    } else {
      final error = json.decode(response.body);
      throw Exception(error['detail'] ?? 'Registration failed');
    }
  }

  /// Login user — with retry on cold-start timeout (Render free tier sleeps)
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    Exception? lastError;
    // Try up to 2 times: first may hit cold-start, second should succeed
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'email': email, 'password': password}),
        ).timeout(
          const Duration(seconds: 60),
          onTimeout: () => throw Exception(
            'Сервер просыпается — подождите и попробуйте снова',
          ),
        );

        if (response.statusCode == 200) {
          final authResponse = AuthResponse.fromJson(json.decode(response.body));
          await _saveAuth(authResponse);
          return authResponse;
        } else {
          final error = json.decode(response.body);
          throw Exception(error['detail'] ?? 'Login failed');
        }
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        // Only retry on network/timeout errors, not on auth errors
        final msg = e.toString();
        final isAuthError = msg.contains('Invalid') || msg.contains('verify');
        if (isAuthError || attempt == 1) rethrow;
        // Brief pause before retry on network error
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    throw lastError!;
  }

  /// Save auth data to local storage
  Future<void> _saveAuth(AuthResponse authResponse) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, authResponse.accessToken);
    await prefs.setString(_userKey, json.encode(authResponse.user.toJson()));
  }

  /// Get saved token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Get saved user
  Future<User?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson == null) return null;
    return User.fromJson(json.decode(userJson));
  }

  /// Check if user is logged in (local check only)
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  /// Verify token is valid on the server
  Future<bool> verifyToken() async {
    final token = await getToken();
    if (token == null) return false;
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Reset password
  Future<void> resetPassword({required String email, required String newPassword}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'new_password': newPassword}),
    );
    if (response.statusCode != 200) {
      final error = json.decode(response.body);
      throw Exception(error['detail'] ?? 'Reset failed');
    }
  }

  /// Update profile fields (any subset)
  Future<User> updateProfile({
    String? name,
    String? firstName,
    String? lastName,
    String? bio,
    bool? openToWork,
    List<String>? skills,
    String? universityName,
    String? specialty,
    int? studyYear,
    String? portfolioUrl,
  }) async {
    final token = await getToken();
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (firstName != null) body['first_name'] = firstName;
    if (lastName != null) body['last_name'] = lastName;
    if (bio != null) body['bio'] = bio;
    if (openToWork != null) body['open_to_work'] = openToWork;
    if (skills != null) body['skills'] = skills;
    if (universityName != null) body['university_name'] = universityName;
    if (specialty != null) body['specialty'] = specialty;
    if (studyYear != null) body['study_year'] = studyYear;
    if (portfolioUrl != null) body['portfolio_url'] = portfolioUrl;

    final response = await http.put(
      Uri.parse('$baseUrl/auth/profile'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: json.encode(body),
    );
    if (response.statusCode == 200) {
      final prefs = await SharedPreferences.getInstance();
      final user = User.fromJson(json.decode(response.body));
      await prefs.setString(_userKey, json.encode(user.toJson()));
      return user;
    } else {
      final error = json.decode(response.body);
      throw Exception(error['detail'] ?? 'Update failed');
    }
  }

  /// Sign in with Google — opens the Google account picker popup
  Future<void> loginWithGoogle() async {
    final account = await _googleSignIn.signIn();
    if (account == null) throw Exception('Вход через Google отменён');

    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) throw Exception('Не удалось получить токен от Google');

    final response = await http.post(
      Uri.parse('$baseUrl/auth/google'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'id_token': idToken}),
    );

    if (response.statusCode == 200) {
      final authResponse = AuthResponse.fromJson(json.decode(response.body));
      await _saveAuth(authResponse);
    } else {
      final error = json.decode(response.body);
      throw Exception(error['detail'] ?? 'Ошибка входа через Google');
    }
  }

  /// Ping the backend so it wakes up from Render free-tier sleep.
  /// Errors are silently ignored — this is best-effort only.
  void warmup() {
    http.get(Uri.parse('$baseUrl/health')).catchError((_) => http.Response('', 0));
  }

  /// Logout (clear saved data)
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    await _googleSignIn.signOut();
  }
}
