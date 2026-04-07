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
    );

    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      // If response has access_token — auto-login (email not required)
      if (body.containsKey('access_token')) {
        final authResponse = AuthResponse.fromJson(body);
        await _saveAuth(authResponse);
        return RegisterResult(requiresVerification: false);
      }
      // Otherwise backend sent verification email
      return RegisterResult(requiresVerification: true);
    } else {
      final error = json.decode(response.body);
      throw Exception(error['detail'] ?? 'Registration failed');
    }
  }

  /// Login user
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final authResponse = AuthResponse.fromJson(json.decode(response.body));
      await _saveAuth(authResponse);
      return authResponse;
    } else {
      final error = json.decode(response.body);
      throw Exception(error['detail'] ?? 'Login failed');
    }
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

  /// Update profile name
  Future<void> updateProfile({required String name}) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/auth/profile'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: json.encode({'name': name}),
    );
    if (response.statusCode == 200) {
      final prefs = await SharedPreferences.getInstance();
      final data = json.decode(response.body);
      final user = User.fromJson(data);
      await prefs.setString(_userKey, json.encode(user.toJson()));
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

  /// Logout (clear saved data)
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    await _googleSignIn.signOut();
  }
}
