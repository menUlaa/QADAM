class User {
  final int id;
  final String email;
  final String name;
  final String firstName;
  final String lastName;
  final bool isAdmin;
  final bool isVerified;

  const User({
    required this.id,
    required this.email,
    required this.name,
    this.firstName = '',
    this.lastName = '',
    this.isAdmin = false,
    this.isVerified = true,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      email: json['email'] as String,
      name: json['name'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      isAdmin: json['is_admin'] as bool? ?? false,
      isVerified: json['is_verified'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'first_name': firstName,
      'last_name': lastName,
      'is_admin': isAdmin,
      'is_verified': isVerified,
    };
  }
}

/// Returned by register() — may require email verification instead of token
class RegisterResult {
  final bool requiresVerification;
  RegisterResult({required this.requiresVerification});
}

class AuthResponse {
  final String accessToken;
  final String tokenType;
  final User user;

  const AuthResponse({
    required this.accessToken,
    required this.tokenType,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
