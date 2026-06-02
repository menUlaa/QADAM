// LinkedIn-style detail panel and empty state for the feed split layout.
// Imported by feed_screen.dart.
import 'package:flutter/material.dart';
import 'package:internship_app2/models/internship.dart';
import 'package:internship_app2/services/api_service.dart';

const _liBlue   = Color(0xFF2164F3);
const _liInk    = Color(0xFF111827);
const _liBody   = Color(0xFF475569);
const _liMuted  = Color(0xFF9CA3AF);
const _liBorder = Color(0xFFE5E7EB);
const _liSurf   = Color(0xFFF8F9FB);

class LinkedInDetailPanel extends StatefulWidget {
  final Internship internship;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;
  final VoidCallback? onClose;

  const LinkedInDetailPanel({
    super.key,
    required this.internship,
    required this.isFavorite,
    required this.onFavoriteToggle,
    this.onClose,
  });

  @override
  State<LinkedInDetailPanel> createState() => _LinkedInDetailPanelState();
}

class _LinkedInDetailPanelState extends State<LinkedInDetailPanel> {
  final _api = ApiService();
  bool _applying = false;
  bool _applied  = false;

  // Enriched data fetched from HH API
  String? _description;
  List<String> _skills = [];
  bool _loadingDetail = false;

  @override
  void initState() {
    super.initState();
    if (widget.internship.isExternal) _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() => _loadingDetail = true);
    try {
      final data = await _api.getHhVacancyDetail(
          widget.internship.id.toString());
      if (mounted) {
        setState(() {
          _description = data['description'] as String?;
          _skills = (data['skills'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          _loadingDetail = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDetail = false);
    }
  }

  static const _palette = [
    Color(0xFF3B82F6), Color(0xFF8B5CF6), Color(0xFF10B981),
    Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFF06B6D4),
  ];

  Color get _accent =>
      _palette[widget.internship.company.hashCode.abs() % _palette.length];

  String get _initials {
    final parts = widget.internship.company.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    final s = widget.internship.company;
    return s.length >= 2 ? s.substring(0, 2).toUpperCase() : s.toUpperCase();
  }

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays} дн. назад';
    if (diff.inHours > 0) return '${diff.inHours} ч. назад';
    return 'только что';
  }

  Future<void> _apply() async {
    final msgCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Подать заявку',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.internship.title,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13, color: _liInk)),
            Text(widget.internship.company,
                style: const TextStyle(fontSize: 12, color: _liBody)),
            const SizedBox(height: 14),
            TextField(
              controller: msgCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Сопроводительное письмо (необязательно)',
                hintStyle: const TextStyle(fontSize: 13, color: _liMuted),
                filled: true,
                fillColor: _liSurf,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _liBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _liBorder),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена', style: TextStyle(color: _liBody))),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _liBlue,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Отправить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _applying = true);
    try {
      final it = widget.internship;
      if (it.isExternal) {
        await _api.applyExternal(
          hhId: it.id.toString(),
          title: it.title,
          company: it.company,
          city: it.city,
          salaryFrom: it.salaryKzt,
          externalUrl: it.externalUrl,
          message: msgCtrl.text,
        );
      } else {
        await _api.apply(it.id, message: msgCtrl.text);
      }
      if (mounted) setState(() => _applied = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.internship;
    final salary = it.salaryKzt != null
        ? '${(it.salaryKzt! / 1000).round()}K ₸/мес'
        : (it.paid ? 'Оплачивается' : null);

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Top bar with back button
          if (widget.onClose != null)
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _liBorder)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  InkWell(
                    onTap: widget.onClose,
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back_ios_new_rounded,
                              size: 14, color: _liBlue),
                          SizedBox(width: 4),
                          Text('Назад',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _liBlue)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              // Company
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE4E2E0)),
                  ),
                  child: Center(
                    child: Text(_initials,
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _accent)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(it.company,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _liBlue)),
                      const SizedBox(height: 3),
                      Row(children: [
                        if (it.city.isNotEmpty) ...[
                          const Icon(Icons.location_on_outlined,
                              size: 13, color: _liMuted),
                          const SizedBox(width: 3),
                          Text(it.city,
                              style: const TextStyle(
                                  fontSize: 13, color: _liMuted)),
                        ],
                        if (it.city.isNotEmpty && it.createdAt != null)
                          const Text(' · ',
                              style:
                                  TextStyle(fontSize: 13, color: _liMuted)),
                        if (it.createdAt != null)
                          Text(_timeAgo(it.createdAt),
                              style: const TextStyle(
                                  fontSize: 13, color: _liMuted)),
                      ]),
                    ],
                  ),
                ),
              ]),

              const SizedBox(height: 16),

              // Title
              Text(it.title,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _liInk,
                      height: 1.2)),

              const SizedBox(height: 12),

              // Meta chips
              Wrap(spacing: 8, runSpacing: 6, children: [
                if (it.format.isNotEmpty)
                  LiChip(Icons.work_outline_rounded, it.format),
                if (salary != null)
                  LiChip(Icons.attach_money_rounded, salary,
                      color: const Color(0xFF16A34A)),
                if (it.isExternal)
                  LiChip(Icons.open_in_new_rounded, 'HH.kz',
                      color: const Color(0xFFCC0000)),
              ]),

              const SizedBox(height: 20),

              // Buttons
              Row(children: [
                SizedBox(
                  height: 40,
                  child: FilledButton(
                    onPressed: _applied || _applying ? null : _apply,
                    style: FilledButton.styleFrom(
                      backgroundColor: _liBlue,
                      disabledBackgroundColor: const Color(0xFFD1D5DB),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    child: _applying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(
                            _applied ? 'Заявка отправлена' : 'Подать заявку',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: widget.onFavoriteToggle,
                    icon: Icon(
                      widget.isFavorite
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_outline_rounded,
                      size: 16,
                    ),
                    label: Text(
                        widget.isFavorite ? 'Сохранено' : 'Сохранить'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _liBlue,
                      backgroundColor: widget.isFavorite
                          ? const Color(0xFFEFF4FF)
                          : null,
                      side: BorderSide(
                          color: widget.isFavorite ? _liBlue : _liBorder),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
              ]),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Divider(height: 1, color: _liBorder),
              ),

              // Description / loading
              if (_loadingDetail) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(
                  color: _liBlue,
                  backgroundColor: Color(0xFFEFF4FF),
                  minHeight: 2,
                ),
                const SizedBox(height: 12),
              ],

              const LiSection('О стажировке'),
              const SizedBox(height: 10),
              Text(
                _description?.isNotEmpty == true
                    ? _description!
                    : it.description.isNotEmpty
                        ? it.description
                        : 'Стажировка предоставляет возможность получить практический опыт работы в команде профессионалов. Вы будете работать над реальными задачами и развивать профессиональные навыки.',
                style: const TextStyle(
                    fontSize: 14, color: _liBody, height: 1.7),
              ),

              // Requirements
              if (it.requirements.isNotEmpty) ...[
                const SizedBox(height: 20),
                const LiSection('Требования'),
                const SizedBox(height: 10),
                ...it.requirements.map(liBullet),
              ],

              // Responsibilities
              if (it.responsibilities.isNotEmpty) ...[
                const SizedBox(height: 20),
                const LiSection('Обязанности'),
                const SizedBox(height: 10),
                ...it.responsibilities.map(liBullet),
              ],

              // Skills — prefer fetched from HH, fallback to model
              if ((_skills.isNotEmpty ? _skills : it.skills).isNotEmpty) ...[
                const SizedBox(height: 20),
                const LiSection('Навыки'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: (_skills.isNotEmpty ? _skills : it.skills)
                      .map((s) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text('#$s',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF6B7280))),
                          ))
                      .toList(),
                ),
              ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget liBullet(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 7),
            child: CircleAvatar(radius: 2.5, backgroundColor: _liBlue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 14, color: _liBody, height: 1.55)),
          ),
        ],
      ),
    );

class LiSection extends StatelessWidget {
  final String text;
  const LiSection(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.w700, color: _liInk));
}

class LiChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const LiChip(this.icon, this.label, {this.color});
  @override
  Widget build(BuildContext context) {
    final c = color ?? _liBody;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: c.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w500, color: c)),
      ]),
    );
  }
}

class EmptyDetailState extends StatelessWidget {
  const EmptyDetailState();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8F9FB),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF4FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.work_outline_rounded,
                size: 34, color: Color(0xFF2164F3)),
          ),
          const SizedBox(height: 16),
          const Text('Выберите вакансию',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827))),
          const SizedBox(height: 8),
          const Text(
            'Нажмите на карточку слева\nчтобы увидеть детали',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14, color: Color(0xFF9CA3AF), height: 1.5),
          ),
        ]),
      ),
    );
  }
}
