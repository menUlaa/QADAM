import 'package:flutter/material.dart';
import 'package:internship_app2/models/internship.dart';
import 'package:internship_app2/services/api_service.dart';
import 'package:internship_app2/services/favorites_service.dart';

// ── Tokens ────────────────────────────────────────────────────────────────────
const _blue   = Color(0xFF2164F3);
const _ink    = Color(0xFF111827);
const _body   = Color(0xFF475569);
const _muted  = Color(0xFF9CA3AF);
const _border = Color(0xFFE5E7EB);
const _surface = Color(0xFFF8F9FB);

// ── Avatar helpers ────────────────────────────────────────────────────────────
const _palette = [
  Color(0xFF3B82F6), Color(0xFF8B5CF6), Color(0xFF10B981), Color(0xFFF59E0B),
  Color(0xFFEF4444), Color(0xFF06B6D4), Color(0xFF84CC16), Color(0xFFF97316),
];

Color _avatarColor(String name) => _palette[name.hashCode.abs() % _palette.length];

String _initials(String name) {
  final parts = name.trim().split(' ');
  if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  if (parts.isNotEmpty && parts[0].length >= 2) return parts[0].substring(0, 2).toUpperCase();
  return name.isNotEmpty ? name[0].toUpperCase() : '?';
}

// ── Salary formatter ──────────────────────────────────────────────────────────
String _fmtSalary(int kzt) {
  if (kzt >= 1000) {
    final k = kzt / 1000;
    return '${k == k.truncateToDouble() ? k.toInt() : k.toStringAsFixed(1)}K ₸';
  }
  return '$kzt ₸';
}

// ── Placeholder content ───────────────────────────────────────────────────────
const _placeholderDescription =
    'Стажировка предоставляет возможность получить практический опыт работы '
    'в команде профессионалов. Вы будете работать над реальными задачами, '
    'развивать профессиональные навыки и строить карьеру в выбранной сфере.';

const _placeholderRequirements = [
  'Желание учиться и развиваться в профессии',
  'Ответственный подход к поставленным задачам',
  'Умение работать в команде',
  'Базовые знания в выбранной области',
];

const _placeholderBenefits = [
  'Работа над реальными проектами с первого дня',
  'Менторство от опытных специалистов команды',
  'Гибкий рабочий график',
  'Официальное трудоустройство / рекомендательное письмо',
  'Возможность перейти в штат после стажировки',
];

// ── Screen ────────────────────────────────────────────────────────────────────

class InternshipDetailScreen extends StatefulWidget {
  final Internship internship;
  const InternshipDetailScreen({super.key, required this.internship});

  @override
  State<InternshipDetailScreen> createState() => _InternshipDetailScreenState();
}

class _InternshipDetailScreenState extends State<InternshipDetailScreen> {
  final _api = ApiService();
  final _favService = FavoritesService();

  bool _isFavorite = false;
  bool _applying   = false;
  bool _applied    = false;

  @override
  void initState() {
    super.initState();
    _loadFavorite();
  }

  Future<void> _loadFavorite() async {
    final ids = await _favService.getAll();
    if (mounted) setState(() => _isFavorite = ids.contains(widget.internship.id));
  }

  Future<void> _toggleFavorite() async {
    final added = await _favService.toggle(widget.internship.id);
    if (mounted) setState(() => _isFavorite = added);
  }

  Future<void> _showApplyDialog() async {
    final msgCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Подать заявку',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.internship.title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: _ink)),
            if (widget.internship.company.isNotEmpty)
              Text(widget.internship.company,
                  style: const TextStyle(fontSize: 13, color: _body)),
            const SizedBox(height: 14),
            TextField(
              controller: msgCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Сопроводительное письмо (необязательно)',
                hintStyle: const TextStyle(fontSize: 13, color: _muted),
                filled: true,
                fillColor: _surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _border),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена', style: TextStyle(color: _body)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _blue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Отправить заявку'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Заявка отправлена!'),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.internship;
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: const Text(
          'Вакансия',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: IconButton(
              key: ValueKey(_isFavorite),
              icon: Icon(
                _isFavorite ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                color: _isFavorite ? _blue : const Color(0xFF374151),
              ),
              onPressed: _toggleFavorite,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Hero card ────────────────────────────────────────────────────
          _HeroCard(
            internship: it,
            isFavorite: _isFavorite,
            applying: _applying,
            applied: _applied,
            onFavorite: _toggleFavorite,
            onApply: _showApplyDialog,
          ),
          const SizedBox(height: 16),

          // ── Info card ────────────────────────────────────────────────────
          _InfoCard(internship: it),
          const SizedBox(height: 16),

          // ── Hashtag chips ────────────────────────────────────────────────
          if (it.tags.isNotEmpty || it.skills.isNotEmpty) ...[
            _ChipsCard(tags: [...it.tags, ...it.skills]),
            const SizedBox(height: 16),
          ],

          // ── Company card ─────────────────────────────────────────────────
          _CompanyCard(company: it.company, city: it.city),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Hero card ─────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final Internship internship;
  final bool isFavorite;
  final bool applying;
  final bool applied;
  final VoidCallback onFavorite;
  final VoidCallback onApply;

  const _HeroCard({
    required this.internship,
    required this.isFavorite,
    required this.applying,
    required this.applied,
    required this.onFavorite,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final it = internship;
    final color = _avatarColor(it.company.isNotEmpty ? it.company : it.title);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Company row
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    _initials(it.company.isNotEmpty ? it.company : it.title),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      it.company.isNotEmpty ? it.company : 'Компания',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: _blue,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (it.city.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 13, color: _muted),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              it.city,
                              style: const TextStyle(fontSize: 13, color: _muted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Job title
          Text(
            it.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: _ink,
              height: 1.25,
            ),
          ),

          const SizedBox(height: 12),

          // Tags
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (it.format.isNotEmpty) _Pill(it.format),
              if (it.paid && it.salaryKzt != null)
                _Pill(_fmtSalary(it.salaryKzt!),
                    bg: const Color(0xFFEAF3DE), fg: const Color(0xFF27500A))
              else if (it.paid)
                _Pill('Оплачивается',
                    bg: const Color(0xFFEAF3DE), fg: const Color(0xFF27500A)),
              if (it.duration.isNotEmpty) _Pill(it.duration),
            ],
          ),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: FilledButton(
                    onPressed: applied || applying ? null : onApply,
                    style: FilledButton.styleFrom(
                      backgroundColor: _blue,
                      disabledBackgroundColor: const Color(0xFFD1D5DB),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: applying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            applied ? 'Заявка отправлена' : 'Подать заявку',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: onFavorite,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _blue,
                      backgroundColor:
                          isFavorite ? const Color(0xFFEFF4FF) : null,
                      side: BorderSide(
                        color:
                            isFavorite ? _blue : const Color(0xFFD1D5DB),
                      ),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isFavorite
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_outline_rounded,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isFavorite ? 'Сохранено' : 'Сохранить',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
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

// ── Info card ─────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final Internship internship;
  const _InfoCard({required this.internship});

  @override
  Widget build(BuildContext context) {
    final it = internship;
    final desc = it.description.isNotEmpty ? it.description : _placeholderDescription;
    final reqs = it.requirements.isNotEmpty ? it.requirements : _placeholderRequirements;
    final benefits = it.responsibilities.isNotEmpty ? it.responsibilities : _placeholderBenefits;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // О стажировке
          _SectionLabel('О стажировке'),
          const SizedBox(height: 10),
          Text(
            desc,
            style: const TextStyle(
              fontSize: 14,
              color: _body,
              height: 1.65,
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Divider(height: 1, color: _border),
          ),

          // Требования
          _SectionLabel('Требования'),
          const SizedBox(height: 10),
          ...reqs.map(_bullet),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Divider(height: 1, color: _border),
          ),

          // Что предлагаем
          _SectionLabel('Что предлагаем'),
          const SizedBox(height: 10),
          ...benefits.map(_bullet),
        ],
      ),
    );
  }
}

// ── Chips card ────────────────────────────────────────────────────────────────

class _ChipsCard extends StatelessWidget {
  final List<String> tags;
  const _ChipsCard({required this.tags});

  @override
  Widget build(BuildContext context) {
    final unique = tags.where((t) => t.isNotEmpty).toSet().toList();
    if (unique.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Стек и навыки',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: _ink),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: unique.map((t) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '#$t',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Company card ──────────────────────────────────────────────────────────────

class _CompanyCard extends StatelessWidget {
  final String company;
  final String city;
  const _CompanyCard({required this.company, required this.city});

  @override
  Widget build(BuildContext context) {
    final name = company.isNotEmpty ? company : 'Компания';
    final color = _avatarColor(name);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    _initials(name),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Text(
                      'О компании',
                      style: TextStyle(fontSize: 12, color: _muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Компания активно приглашает стажёров и молодых специалистов. '
            'Присоединяйся к команде профессионалов и развивай навыки на реальных проектах.',
            style: TextStyle(fontSize: 13, color: _body, height: 1.55),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {},
            child: const Text(
              'Смотреть все вакансии компании →',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _blue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: _ink,
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const _Pill(
    this.label, {
    this.bg = const Color(0xFFF3F4F6),
    this.fg = const Color(0xFF6B7280),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: fg)),
    );
  }
}

Widget _bullet(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: CircleAvatar(radius: 2.5, backgroundColor: _blue),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, color: _body, height: 1.55),
          ),
        ),
      ],
    ),
  );
}
