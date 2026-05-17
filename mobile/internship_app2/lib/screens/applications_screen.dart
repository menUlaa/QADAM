import 'package:flutter/material.dart';
import 'package:internship_app2/services/api_service.dart';

// ── Design tokens (matches landing_screen palette) ────────────────────────────
const _ink    = Color(0xFF0F172A);
const _body   = Color(0xFF475569);
const _muted  = Color(0xFF94A3B8);
const _blue   = Color(0xFF2563EB);
const _violet = Color(0xFF7C3AED);
const _green  = Color(0xFF16A34A);
const _amber  = Color(0xFFD97706);
const _red    = Color(0xFFDC2626);
const _border = Color(0xFFE2E8F0);
const _bg     = Color(0xFFFFFFFF);
const _surface = Color(0xFFF8FAFC);

// ── Status config ─────────────────────────────────────────────────────────────
class _StatusCfg {
  final String label;
  final Color color;
  final Color bg;
  final IconData icon;
  const _StatusCfg(this.label, this.color, this.bg, this.icon);
}

const _statuses = {
  'pending':   _StatusCfg('На рассмотрении', _amber,  Color(0xFFFFFBEB), Icons.hourglass_empty_rounded),
  'reviewed':  _StatusCfg('Просмотрено',     _blue,   Color(0xFFEFF6FF), Icons.visibility_outlined),
  'interview': _StatusCfg('Собеседование',   _violet, Color(0xFFF5F3FF), Icons.record_voice_over_outlined),
  'offer':     _StatusCfg('Оффер!',          _green,  Color(0xFFF0FDF4), Icons.celebration_outlined),
  'accepted':  _StatusCfg('Принят',          _green,  Color(0xFFF0FDF4), Icons.check_circle_outline_rounded),
  'rejected':  _StatusCfg('Отказ',           _red,    Color(0xFFFEF2F2), Icons.cancel_outlined),
};

_StatusCfg _cfgFor(String status) =>
    _statuses[status] ??
    const _StatusCfg('Неизвестно', _muted, _surface, Icons.help_outline_rounded);

// Pipeline stages (ordered)
const _pipeline = ['pending', 'reviewed', 'interview', 'offer', 'accepted'];

class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _apps = [];
  bool _loading = true;
  String _filter = 'all'; // all | active | offer | rejected

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
        return _apps.where((a) =>
            (a['status'] as String? ?? '') == 'offer' ||
            (a['status'] as String? ?? '') == 'accepted').toList();
      case 'rejected':
        return _apps.where((a) =>
            (a['status'] as String? ?? '') == 'rejected').toList();
      default:
        return _apps;
    }
  }

  // Count by status
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
                  ? const Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _blue))
                  : _apps.isEmpty
                      ? _EmptyState()
                      : _filtered.isEmpty
                          ? _EmptyFilter()
                          : RefreshIndicator(
                              onRefresh: _load,
                              color: _blue,
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 12, 16, 24),
                                itemCount: _filtered.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (ctx, i) =>
                                    _AppCard(app: _filtered[i]),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

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
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _ink,
              letterSpacing: -0.5,
            ),
          ),
          if (total > 0) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_blue, _violet]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$total',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary row — pipeline funnel
// ─────────────────────────────────────────────────────────────────────────────

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
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: count > 0 ? cfg.color : _muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cfg.label,
                    style: TextStyle(
                      fontSize: 9,
                      color: count > 0 ? cfg.color : _muted,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 5),
                  Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: count > 0
                          ? cfg.color.withValues(alpha: 0.5)
                          : _border,
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

// ─────────────────────────────────────────────────────────────────────────────
// Filter bar
// ─────────────────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final String selected;
  final void Function(String) onChanged;
  final Map<String, int> counts;
  const _FilterBar(
      {required this.selected,
      required this.onChanged,
      required this.counts});

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
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? _blue : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? _blue : _border,
                  ),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
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

// ─────────────────────────────────────────────────────────────────────────────
// Application card
// ─────────────────────────────────────────────────────────────────────────────

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

  String _initials(String name) => name
      .trim()
      .split(' ')
      .map((w) => w.isNotEmpty ? w[0] : '')
      .take(2)
      .join()
      .toUpperCase();

  @override
  Widget build(BuildContext context) {
    final status = app['status'] as String? ?? 'pending';
    final cfg = _cfgFor(status);
    final title = app['internship_title'] as String? ??
        app['title'] as String? ?? 'Стажировка';
    final company = app['company_name'] as String? ??
        app['company'] as String? ?? '';
    final appliedAt = app['applied_at'] as String? ??
        app['created_at'] as String?;
    final message = app['message'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Company avatar
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: cfg.color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: cfg.color.withValues(alpha: 0.2)),
                  ),
                  child: Center(
                    child: Text(
                      _initials(company.isEmpty ? title : company),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: cfg.color,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Title + company
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (company.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          company,
                          style: const TextStyle(
                              fontSize: 13,
                              color: _blue,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: cfg.bg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: cfg.color.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(cfg.icon, size: 12, color: cfg.color),
                      const SizedBox(width: 4),
                      Text(
                        cfg.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: cfg.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Pipeline dots
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: _PipelineDots(status: status),
          ),

          // Footer: date + message snippet
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 12, color: _muted),
                const SizedBox(width: 5),
                Text(
                  _timeAgo(appliedAt),
                  style: const TextStyle(
                      fontSize: 12, color: _muted),
                ),
                if (message != null && message.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.chat_bubble_outline_rounded,
                      size: 12, color: _muted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                          fontSize: 12, color: _muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Interview / offer highlight
          if (status == 'interview' || status == 'offer') ...[
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: cfg.color.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: cfg.color.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                    status == 'interview'
                        ? Icons.tips_and_updates_outlined
                        : Icons.celebration_outlined,
                    size: 14,
                    color: cfg.color,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      status == 'interview'
                          ? 'Готовься к собеседованию — воспользуйся AI подготовкой'
                          : 'Тебе предложили оффер! Скоро с тобой свяжутся.',
                      style: TextStyle(
                        fontSize: 12,
                        color: cfg.color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pipeline dots row
// ─────────────────────────────────────────────────────────────────────────────

class _PipelineDots extends StatelessWidget {
  final String status;
  const _PipelineDots({required this.status});

  @override
  Widget build(BuildContext context) {
    final isRejected = status == 'rejected';
    final currentIdx = isRejected ? -1 : _pipeline.indexOf(status);

    return Row(
      children: List.generate(_pipeline.length * 2 - 1, (i) {
        if (i.isOdd) {
          // Connector line
          final stageIdx = i ~/ 2;
          final passed = !isRejected && stageIdx < currentIdx;
          return Expanded(
            child: Container(
              height: 2,
              color: passed
                  ? _blue.withValues(alpha: 0.4)
                  : _border,
            ),
          );
        }
        // Dot
        final dotIdx = i ~/ 2;
        final isActive = !isRejected && dotIdx == currentIdx;
        final isPassed = !isRejected && dotIdx < currentIdx;
        final cfg = _cfgFor(_pipeline[dotIdx]);

        return Container(
          width: isActive ? 10 : 8,
          height: isActive ? 10 : 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? cfg.color
                : isPassed
                    ? _blue.withValues(alpha: 0.35)
                    : _border,
            border: isActive
                ? Border.all(
                    color: cfg.color.withValues(alpha: 0.3), width: 2)
                : null,
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty states
// ─────────────────────────────────────────────────────────────────────────────

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
                gradient: const LinearGradient(
                    colors: [_blue, _violet]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 36),
            ),
            const SizedBox(height: 20),
            const Text(
              'Ещё нет заявок',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Подай заявку на стажировку — и она\nпоявится здесь',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: _body, height: 1.5),
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
      child: Text(
        'Нет заявок по этому фильтру',
        style: TextStyle(fontSize: 14, color: _muted),
      ),
    );
  }
}
