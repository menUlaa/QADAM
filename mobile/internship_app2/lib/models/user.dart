class User {
  final int id;
  final String email;
  final String name;
  final String firstName;
  final String lastName;
  final bool isAdmin;
  final bool isVerified;
  final bool isGraduate;
  final bool openToWork;
  final String? bio;
  final String? universityName;
  final String? specialty;
  final int? studyYear;
  final String? cvUrl;
  final String? cvFilename;
  final String? cvUploadedAt;
  final List<String> skills;
  final String? portfolioUrl;

  const User({
    required this.id,
    required this.email,
    required this.name,
    this.firstName = '',
    this.lastName = '',
    this.isAdmin = false,
    this.isVerified = true,
    this.isGraduate = false,
    this.openToWork = true,
    this.bio,
    this.universityName,
    this.specialty,
    this.studyYear,
    this.cvUrl,
    this.cvFilename,
    this.cvUploadedAt,
    this.skills = const [],
    this.portfolioUrl,
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
      isGraduate: json['is_graduate'] as bool? ?? false,
      openToWork: json['open_to_work'] as bool? ?? true,
      bio: json['bio'] as String?,
      universityName: json['university_name'] as String?,
      specialty: json['specialty'] as String?,
      studyYear: json['study_year'] as int?,
      cvUrl: json['cv_url'] as String?,
      cvFilename: json['cv_filename'] as String?,
      cvUploadedAt: json['cv_uploaded_at'] as String?,
      skills: (json['skills'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      portfolioUrl: json['portfolio_url'] as String?,
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
      'is_graduate': isGraduate,
      'open_to_work': openToWork,
      'bio': bio,
      'university_name': universityName,
      'specialty': specialty,
      'study_year': studyYear,
      'cv_url': cvUrl,
      'cv_filename': cvFilename,
      'cv_uploaded_at': cvUploadedAt,
      'skills': skills,
      'portfolio_url': portfolioUrl,
    };
  }

  User copyWith({
    String? name,
    String? firstName,
    String? lastName,
    bool? openToWork,
    String? bio,
    String? universityName,
    String? specialty,
    int? studyYear,
    String? cvUrl,
    String? cvFilename,
    String? cvUploadedAt,
    List<String>? skills,
    String? portfolioUrl,
  }) {
    return User(
      id: id,
      email: email,
      name: name ?? this.name,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      isAdmin: isAdmin,
      isVerified: isVerified,
      isGraduate: isGraduate,
      openToWork: openToWork ?? this.openToWork,
      bio: bio ?? this.bio,
      universityName: universityName ?? this.universityName,
      specialty: specialty ?? this.specialty,
      studyYear: studyYear ?? this.studyYear,
      cvUrl: cvUrl ?? this.cvUrl,
      cvFilename: cvFilename ?? this.cvFilename,
      cvUploadedAt: cvUploadedAt ?? this.cvUploadedAt,
      skills: skills ?? this.skills,
      portfolioUrl: portfolioUrl ?? this.portfolioUrl,
    );
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
