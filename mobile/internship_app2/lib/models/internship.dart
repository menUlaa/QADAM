/// Internship data model
class Internship {
  final int id;
  final String title;
  final String company;
  final String city;
  final String format; // Remote/Hybrid/On-site
  final bool paid;
  final int? salaryKzt;
  final String duration;
  final String description;
  final List<String> responsibilities;
  final List<String> requirements;
  final List<String> skills;
  final String contactEmail;
  final List<String> tags;
  final String category;
  final DateTime? createdAt;

  const Internship({
    required this.id,
    required this.title,
    required this.company,
    required this.city,
    required this.format,
    required this.paid,
    required this.salaryKzt,
    required this.duration,
    required this.description,
    required this.responsibilities,
    required this.requirements,
    required this.skills,
    required this.contactEmail,
    required this.tags,
    this.category = 'IT',
    this.createdAt,
  });

  /// Create Internship from JSON (API response)
  factory Internship.fromJson(Map<String, dynamic> json) {
    return Internship(
      id: json['id'] as int,
      title: json['title'] as String,
      company: json['company'] as String,
      city: json['city'] as String? ?? '',
      format: json['format'] as String? ?? 'Hybrid',
      paid: json['paid'] as bool? ?? false,
      salaryKzt: json['salary_kzt'] as int?,
      duration: json['duration'] as String? ?? '',
      description: json['description'] as String? ?? '',
      responsibilities: (json['responsibilities'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      requirements: (json['requirements'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      skills: (json['skills'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      contactEmail: json['contact_email'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      category: json['category'] as String? ?? 'IT',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  /// Convert Internship to JSON (for API requests)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'company': company,
      'city': city,
      'format': format,
      'paid': paid,
      'salary_kzt': salaryKzt,
      'duration': duration,
      'description': description,
      'responsibilities': responsibilities,
      'requirements': requirements,
      'skills': skills,
      'contact_email': contactEmail,
      'tags': tags,
      'category': category,
    };
  }
}

/// Demo data for development
class DemoData {
  static List<Internship> internships() {
    return const [
      Internship(
        id: 1,
        title: 'Junior Flutter Intern',
        company: 'TechNova',
        city: 'Astana',
        format: 'Hybrid',
        paid: true,
        salaryKzt: 150000,
        duration: '3 months',
        description:
            'Работа с мобильным приложением, UI, интеграции с API. Поможем войти в Flutter экосистему.',
        responsibilities: [
          'Собирать UI экраны по дизайну (Material 3)',
          'Подключать API и отображать данные',
          'Исправлять баги и делать небольшие улучшения',
        ],
        requirements: [
          'Базовый Dart / Flutter',
          'Понимание Stateful/Stateless, навигации',
          'Готовность учиться и принимать ревью',
        ],
        skills: ['Flutter', 'Dart', 'REST', 'Git', 'UI'],
        contactEmail: 'hr@technova.kz',
        tags: ['flutter', 'mobile', 'ui'],
      ),
      Internship(
        id: 2,
        title: 'Data Analyst Intern',
        company: 'FinPulse',
        city: 'Almaty',
        format: 'On-site',
        paid: true,
        salaryKzt: 120000,
        duration: '2–3 months',
        description:
            'Стажировка для аналитика: отчеты, данные, простые модели, SQL запросы. Реальные задачи.',
        responsibilities: [
          'Собирать данные из источников',
          'Писать SQL запросы и делать отчеты',
          'Помогать команде с аналитикой',
        ],
        requirements: [
          'Excel/Google Sheets уверенно',
          'Базовый SQL',
          'Логическое мышление',
        ],
        skills: ['SQL', 'Excel', 'Power BI', 'Analytics'],
        contactEmail: 'interns@finpulse.kz',
        tags: ['data', 'sql', 'bi'],
      ),
      Internship(
        id: 3,
        title: 'Backend Intern (FastAPI)',
        company: 'BuildKZ',
        city: 'Shymkent',
        format: 'Remote',
        paid: false,
        salaryKzt: null,
        duration: '1–2 months',
        description:
            'Помощь с backend на FastAPI: роуты, схемы, простая интеграция с БД.',
        responsibilities: [
          'Делать API эндпоинты',
          'Писать Pydantic схемы',
          'Покрывать базовыми тестами',
        ],
        requirements: [
          'Python базовый',
          'FastAPI/REST понимание',
          'Аккуратность с кодом',
        ],
        skills: ['Python', 'FastAPI', 'REST', 'Git'],
        contactEmail: 'team@buildkz.kz',
        tags: ['backend', 'fastapi', 'python'],
      ),
    ];
  }
}
