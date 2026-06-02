import 'package:flutter/material.dart';
import 'package:internship_app2/models/internship.dart';
import 'package:internship_app2/screens/internship_detail_screen.dart';
import 'package:internship_app2/services/api_service.dart';
import 'package:internship_app2/services/base_url.dart';
import 'package:url_launcher/url_launcher.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _ink    = Color(0xFF0F172A);
const _body   = Color(0xFF475569);
const _muted  = Color(0xFF94A3B8);
const _blue   = Color(0xFF2164F3);
const _violet = Color(0xFF7C3AED);
const _green  = Color(0xFF16A34A);
const _red    = Color(0xFFDC2626);
const _border = Color(0xFFE5E7EB);
const _bg     = Color(0xFFFFFFFF);
const _surface = Color(0xFFF8F9FB);

// ── Status config ─────────────────────────────────────────────────────────────
class _StatusCfg {
  final String label;
  final Color color;
  final Color bg;
  final IconData icon;
  const _StatusCfg(this.label, this.color, this.bg, this.icon);
}

const _statuses = {
  'pending':   _StatusCfg('На рассмотрении', Color(0xFFF59E0B), Color(0xFFFFFBEB), Icons.hourglass_empty_rounded),
  'reviewed':  _StatusCfg('Просмотрено',     Color(0xFF6366F1), Color(0xFFEEF2FF), Icons.visibility_outlined),
  'interview': _StatusCfg('Собеседование',   Color(0xFF2164F3), Color(0xFFEFF4FF), Icons.record_voice_over_outlined),
  'offer':     _StatusCfg('Оффер!',          Color(0xFF16A34A), Color(0xFFF0FDF4), Icons.celebration_outlined),
  'accepted':  _StatusCfg('Принят',          Color(0xFF16A34A), Color(0xFFF0FDF4), Icons.check_circle_outline_rounded),
  'rejected':  _StatusCfg('Отказ',           Color(0xFFDC2626), Color(0xFFFEF2F2), Icons.cancel_outlined),
};

_StatusCfg _cfgFor(String status) =>
    _statuses[status] ??
    const _StatusCfg('Неизвестно', _muted, _surface, Icons.help_outline_rounded);

const _pipeline = ['pending', 'reviewed', 'interview', 'offer', 'accepted'];
const _pipelineLabels = ['Подана', 'Просмотрено', 'Собеседование', 'Оффер', 'Принят'];

// ── Avatar color palette ──────────────────────────────────────────────────────
const _avatarPalette = [
  Color(0xFF3B82F6),
  Color(0xFF8B5CF6),
  Color(0xFF10B981),
  Color(0xFFF59E0B),
  Color(0xFFEF4444),
  Color(0xFF06B6D4),
  Color(0xFF84CC16),
  Color(0xFFF97316),
];

Color _avatarColor(String name) =>
    _avatarPalette[name.hashCode.abs() % _avatarPalette.length];

String _initials(String name) {
  final parts = name.trim().split(' ');
  if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  if (parts.isNotEmpty && parts[0].length >= 2) {
    return parts[0].substring(0, 2).toUpperCase();
  }
  return name.isNotEmpty ? name[0].toUpperCase() : '?';
}

// ── Main screen ───────────────────────────────────────────────────────────────
class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _apps = [];
  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final apps = await _api.getMyApplications();
      if (mounted) setState(() { _apps = apps; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    switch (_filter) {
      case 'active':
        return _apps.where((a) {
          final s = a['status'] as String? ?? '';
          return ['pending', 'reviewed', 'interview'].contains(s);
        }).toList();
      case 'offer':
        return _apps.where((a) {
          final s = a['status'] as String? ?? '';
          return s == 'offer' || s == 'accepted';
        }).toList();
      case 'rejected':
        return _apps.where((a) =>
            (a['status'] as String? ?? '') == 'rejected').toList();
      default:
        return _apps;
    }
  }

  int _countByStatus(String status) =>
      _apps.where((a) => (a['status'] as String? ?? '') == status).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(total: _apps.length),
            if (!_loading && _apps.isNotEmpty) ...[
              _SummaryRow(apps: _apps),
              _FilterBar(
                selected: _filter,
                onChanged: (v) => setState(() => _filter = v),
                counts: {
                  'all': _apps.length,
                  'active': _apps.where((a) {
                    final s = a['status'] as String? ?? '';
                    return ['pending', 'reviewed', 'interview'].contains(s);
                  }).length,
                  'offer': _apps.where((a) {
                    final s = a['status'] as String? ?? '';
                    return s == 'offer' || s == 'accepted';
                  }).length,
                  'rejected': _countByStatus('rejected'),
                },
              ),
            ],
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: _blue))
                  : _apps.isEmpty
                      ? _EmptyState()
                      : _filtered.isEmpty
                          ? _EmptyFilter()
                          : RefreshIndicator(
                              onRefresh: _load,
                              color: _blue,
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                                itemCount: _filtered.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 10),
                                itemBuilder: (ctx, i) => _AppCard(app: _filtered[i]),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header (unchanged) ────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final int total;
  const _Header({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      child: Row(
        children: [
          const Text(
            'Мои заявки',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _ink, letterSpacing: -0.5),
          ),
          if (total > 0) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_blue, _violet]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$total',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Summary row (unchanged) ───────────────────────────────────────────────────
class _SummaryRow extends StatelessWidget {
  final List<Map<String, dynamic>> apps;
  const _SummaryRow({required this.apps});

  int _count(String status) =>
      apps.where((a) => (a['status'] as String? ?? '') == status).length;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: _pipeline.map((s) {
          final cfg = _cfgFor(s);
          final count = _count(s);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$count',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: count > 0 ? cfg.color : _muted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cfg.label,
                    style: TextStyle(fontSize: 9, color: count > 0 ? cfg.color : _muted, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 5),
                  Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: count > 0 ? cfg.color.withValues(alpha: 0.5) : _border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Filter bar (unchanged) ────────────────────────────────────────────────────
class _FilterBar extends StatelessWidget {
  final String selected;
  final void Function(String) onChanged;
  final Map<String, int> counts;
  const _FilterBar({required this.selected, required this.onChanged, required this.counts});

  static const _filters = [
    ('all', 'Все'),
    ('active', 'Активные'),
    ('offer', 'Офферы'),
    ('rejected', 'Архив'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      color: _bg,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: _filters.map((f) {
          final isSelected = selected == f.$1;
          final count = counts[f.$1] ?? 0;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(f.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? _blue : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? _blue : _border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      f.$2,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : _body,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.25)
                              : _blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : _blue,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Application card ──────────────────────────────────────────────────────────
class _AppCard extends StatelessWidget {
  final Map<String, dynamic> app;
  const _AppCard({required this.app});

  String _timeAgo(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'Сегодня';
    if (diff.inDays == 1) return 'Вчера';
    if (diff.inDays < 7) return '${diff.inDays} дн. назад';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} нед. назад';
    return '${(diff.inDays / 30).floor()} мес. назад';
  }

  static String _fmtSalary(int kzt) {
    if (kzt >= 1000) {
      final k = kzt / 1000;
      return '${k == k.truncateToDouble() ? k.toInt() : k.toStringAsFixed(1)}K ₸';
    }
    return '$kzt ₸';
  }

  Internship _toInternship() {
    return Internship(
      id: app['internship_id'] as int? ?? app['id'] as int? ?? 0,
      title: app['internship_title'] as String? ?? app['title'] as String? ?? 'Стажировка',
      company: app['company_name'] as String? ?? app['company'] as String? ?? '',
      city: app['city'] as String? ?? app['internship_city'] as String? ?? '',
      format: app['format'] as String? ?? 'Hybrid',
      paid: (app['salary_kzt'] as num? ?? 0) > 0,
      salaryKzt: (app['salary_kzt'] as num?)?.toInt(),
      duration: app['duration'] as String? ?? '',
      description: app['description'] as String? ?? '',
      responsibilities: (app['responsibilities'] as List?)?.map((e) => e.toString()).toList() ?? [],
      requirements: (app['requirements'] as List?)?.map((e) => e.toString()).toList() ?? [],
      skills: (app['skills'] as List?)?.map((e) => e.toString()).toList() ?? [],
      tags: (app['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      contactEmail: app['contact_email'] as String? ?? '',
    );
  }

  void _showDetails(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => InternshipDetailScreen(internship: _toInternship()),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
            child: child,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 260),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status   = app['status'] as String? ?? 'pending';
    final cfg      = _cfgFor(status);
    final title    = app['internship_title'] as String? ?? app['title'] as String? ?? 'Стажировка';
    final company  = app['company_name'] as String? ?? app['company'] as String? ?? '';
    final city     = app['city'] as String? ?? app['internship_city'] as String? ?? '';
    final format   = app['format'] as String? ?? app['internship_format'] as String? ?? '';
    final salaryKzt = app['salary_kzt'] as int? ?? app['internship_salary_kzt'] as int?;
    final paid     = app['paid'] as bool? ?? (salaryKzt != null && salaryKzt > 0);
    final duration = app['duration'] as String? ?? app['internship_duration'] as String? ?? '';
    final appliedAt = app['applied_at'] as String? ?? app['created_at'] as String?;
    final avatarName = company.isNotEmpty ? company : title;

    final hasTags = format.isNotEmpty ||
        (paid && salaryKzt != null) ||
        duration.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: avatar + company/city + status ───────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _avatarColor(avatarName).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    _initials(avatarName),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _avatarColor(avatarName),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Company + city
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      company.isNotEmpty ? company : title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _blue,
                      ),
                    ),
                    if (city.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 11, color: _muted),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              city,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: _muted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cfg.bg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: cfg.color.withValues(alpha: 0.3)),
                ),
                child: Text(
                  cfg.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cfg.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Job title ─────────────────────────────────────────────
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: _ink,
              height: 1.3,
            ),
          ),

          // ── Tags ──────────────────────────────────────────────────
          if (hasTags) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 5,
              runSpacing: 4,
              children: [
                if (format.isNotEmpty) _TagPill(format),
                if (paid && salaryKzt != null)
                  _TagPill(
                    _fmtSalary(salaryKzt),
                    bg: const Color(0xFFEAF3DE),
                    fg: const Color(0xFF27500A),
                  ),
                if (duration.isNotEmpty) _TagPill(duration),
              ],
            ),
          ],

          const SizedBox(height: 14),

          // ── Progress stepper ──────────────────────────────────────
          _ProgressStepper(status: status),

          const SizedBox(height: 12),

          // ── Bottom row: date + Подробнее ──────────────────────────
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 13, color: _muted),
              const SizedBox(width: 5),
              Text(
                _timeAgo(appliedAt),
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _showDetails(context),
                child: const Text(
                  'Подробнее',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _blue,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Tag pill ──────────────────────────────────────────────────────────────────
class _TagPill extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const _TagPill(
    this.label, {
    this.bg = const Color(0xFFF3F4F6),
    this.fg = const Color(0xFF6B7280),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: fg),
      ),
    );
  }
}

// ── Progress stepper ──────────────────────────────────────────────────────────
class _ProgressStepper extends StatelessWidget {
  final String status;
  static const _circleD = 20.0;

  const _ProgressStepper({required this.status});

  @override
  Widget build(BuildContext context) {
    final isRejected = status == 'rejected';
    final allPassed  = status == 'accepted';
    final currentIdx = isRejected ? -1 : _pipeline.indexOf(status);

    return LayoutBuilder(
      builder: (_, constraints) {
        final w     = constraints.maxWidth;
        final slotW = w / 5;

        return Column(
          children: [
            // Circles + connecting lines
            SizedBox(
              height: _circleD,
              child: Stack(
                children: [
                  // Lines (drawn behind circles)
                  Positioned(
                    left: slotW / 2,
                    right: slotW / 2,
                    top: (_circleD - 2) / 2,
                    child: Row(
                      children: List.generate(4, (i) {
                        final filled = allPassed || i < currentIdx;
                        return Expanded(
                          child: Container(
                            height: 2,
                            color: filled ? _blue : _border,
                          ),
                        );
                      }),
                    ),
                  ),
                  // Circles (drawn on top)
                  Row(
                    children: List.generate(5, (i) {
                      final isPassed  = allPassed || i < currentIdx;
                      final isCurrent = !allPassed && i == currentIdx;

                      Color bg;
                      Widget inner;
                      double size;

                      if (isPassed) {
                        bg    = _blue;
                        size  = 18;
                        inner = const Icon(Icons.check_rounded, size: 10, color: Colors.white);
                      } else if (isCurrent) {
                        bg    = const Color(0xFFF59E0B);
                        size  = _circleD;
                        inner = Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        );
                      } else {
                        bg    = _border;
                        size  = 16;
                        inner = const SizedBox.shrink();
                      }

                      return Expanded(
                        child: Center(
                          child: Container(
                            width: size,
                            height: size,
                            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                            child: Center(child: inner),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 5),

            // Labels
            Row(
              children: List.generate(5, (i) {
                final isPassed  = allPassed || i < currentIdx;
                final isCurrent = !allPassed && i == currentIdx;

                final Color textColor;
                if (isPassed) {
                  textColor = _blue;
                } else if (isCurrent) {
                  textColor = const Color(0xFFF59E0B);
                } else {
                  textColor = _muted;
                }

                return Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _pipelineLabels[i],
                      style: TextStyle(
                        fontSize: 11,
                        color: textColor,
                        fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }
}

// ── Details bottom sheet ──────────────────────────────────────────────────────
class _AppDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> app;
  const _AppDetailsSheet({required this.app});

  @override
  Widget build(BuildContext context) {
    final title    = app['internship_title'] as String? ?? app['title'] as String? ?? 'Стажировка';
    final company  = app['company_name'] as String? ?? app['company'] as String? ?? '';
    final status   = app['status'] as String? ?? 'pending';
    final cfg      = _cfgFor(status);
    final message  = app['message'] as String?;
    final cvUrl    = app['cv_url'] as String?;
    final appliedAt = app['applied_at'] as String? ?? app['created_at'] as String?;

    String? dateStr;
    if (appliedAt != null) {
      final dt = DateTime.tryParse(appliedAt);
      if (dt != null) {
        dateStr = '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
      }
    }

    return Container(
      decoration: const BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        20, 16, 20, MediaQuery.paddingOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: _border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title + status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (company.isNotEmpty)
                      Text(
                        company,
                        style: const TextStyle(fontSize: 13, color: _blue, fontWeight: FontWeight.w600),
                      ),
                    const SizedBox(height: 3),
                    Text(
                      title,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _ink),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: cfg.bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cfg.color.withValues(alpha: 0.3)),
                ),
                child: Text(
                  cfg.label,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cfg.color),
                ),
              ),
            ],
          ),

          if (dateStr != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 13, color: _muted),
                const SizedBox(width: 6),
                Text('Подано $dateStr', style: const TextStyle(fontSize: 13, color: _muted)),
              ],
            ),
          ],

          // Cover letter
          if (message != null && message.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Сопроводительное письмо',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _body, letterSpacing: 0.3),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: Text(
                message,
                style: const TextStyle(fontSize: 13, color: _ink, height: 1.55),
              ),
            ),
          ],

          // CV link
          if (cvUrl != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () async {
                final url = Uri.parse('$apiBaseUrl$cvUrl');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.description_outlined, size: 16),
              label: const Text('Открыть резюме'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _blue,
                side: const BorderSide(color: _blue),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ],

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ── Empty states ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_blue, _violet]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 20),
            const Text(
              'Ещё нет заявок',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _ink),
            ),
            const SizedBox(height: 8),
            const Text(
              'Подай заявку на стажировку — и она\nпоявится здесь',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: _body, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFilter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Нет заявок по этому фильтру', style: TextStyle(fontSize: 14, color: _muted)),
    );
  }
}
