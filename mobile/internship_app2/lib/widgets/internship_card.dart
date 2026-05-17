import 'package:flutter/material.dart';
import 'package:internship_app2/l10n/strings.dart';
import 'package:internship_app2/models/internship.dart';
import 'package:internship_app2/screens/ai_chat_screen.dart';

const _categoryColors = {
  'IT':        Color(0xFF2164F3),
  'Финансы':   Color(0xFF047857),
  'Дизайн':    Color(0xFF7C3AED),
  'Маркетинг': Color(0xFFDC2626),
  'HR':        Color(0xFFD97706),
};

Color _colorFor(String cat) => _categoryColors[cat] ?? const Color(0xFF2164F3);

String _timeAgo(DateTime? dt) {
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  final lang = localeNotifier.value;
  if (diff.inDays == 0) return lang == 'en' ? 'Today' : 'Сегодня';
  if (diff.inDays < 7) {
    final d = diff.inDays;
    return lang == 'en' ? '${d}d ago' : '$d дн. назад';
  }
  if (diff.inDays < 30) {
    final w = (diff.inDays / 7).floor();
    return lang == 'en' ? '${w}w ago' : '$w нед. назад';
  }
  final m = (diff.inDays / 30).floor();
  return lang == 'en' ? '${m}mo ago' : '$m мес. назад';
}

bool _isNew(DateTime? dt) => dt != null && DateTime.now().difference(dt).inDays < 3;

// ── Card ──────────────────────────────────────────────────────────────────────

class InternshipCard extends StatelessWidget {
  final Internship internship;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;
  final void Function(String tag)? onTagTap;

  const InternshipCard({
    super.key,
    required this.internship,
    required this.onTap,
    this.isFavorite = false,
    this.onFavoriteToggle,
    this.onTagTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _colorFor(internship.category);
    final isNewPost = _isNew(internship.createdAt);
    final dateStr = _timeAgo(internship.createdAt);
    final tags = internship.tags.where((t) => t.isNotEmpty).take(3).toList();

    final initials = internship.company
        .trim()
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          hoverColor: const Color(0x042164F3),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE4E2E0)),
            ),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Row 1: Logo + Company + Bookmark ────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Company logo
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE4E2E0)),
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: accent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            internship.company,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2557A7), // Indeed-style blue company name
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (internship.city.isNotEmpty) ...[
                                const Icon(Icons.location_on_outlined,
                                    size: 12, color: Color(0xFF767676)),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    internship.city,
                                    style: const TextStyle(
                                        fontSize: 12, color: Color(0xFF767676)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Badges + bookmark
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: onFavoriteToggle,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              transitionBuilder: (child, anim) =>
                                  ScaleTransition(scale: anim, child: child),
                              child: Icon(
                                isFavorite
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_outline_rounded,
                                key: ValueKey(isFavorite),
                                size: 22,
                                color: isFavorite
                                    ? const Color(0xFF2164F3)
                                    : const Color(0xFFB8B8B8),
                              ),
                            ),
                          ),
                        ),
                        if (isNewPost) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD1FAE5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Новое',
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF065F46))),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // ── Row 2: Title + Match ─────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        internship.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (internship.matchScore != null) ...[
                      const SizedBox(width: 8),
                      _MatchBadge(score: internship.matchScore!),
                    ],
                  ],
                ),

                const SizedBox(height: 10),

                // ── Row 3: Format · Salary · Duration ────────────────────────
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _tag(internship.format, outlined: true),
                    if (internship.salaryKzt != null)
                      _salaryTag(internship.salaryKzt!),
                    if (!internship.paid)
                      _tag('Волонтёрство', color: const Color(0xFF6B7280), outlined: true),
                    if (internship.duration.isNotEmpty)
                      _tag(internship.duration, outlined: true),
                  ],
                ),

                // ── Row 4: Hashtags + Date ───────────────────────────────────
                if (tags.isNotEmpty || dateStr.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: tags.map((tag) => MouseRegion(
                            cursor: onTagTap != null ? SystemMouseCursors.click : MouseCursor.defer,
                            child: GestureDetector(
                              onTap: onTagTap != null ? () => onTagTap!(tag) : null,
                              child: Text(
                                '#$tag',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: onTagTap != null
                                      ? const Color(0xFF2557A7)
                                      : const Color(0xFF767676),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          )).toList(),
                        ),
                      ),
                      if (dateStr.isNotEmpty)
                        Text(dateStr,
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF9CA3AF))),
                    ],
                  ),
                ],

                // ── Row 5: AI quick actions ───────────────────────────────────
                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFF0F0F0)),
                const SizedBox(height: 8),
                _QuickAiRow(internship: internship),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tag(String label, {Color? color, bool outlined = false}) {
    final c = color ?? const Color(0xFF595959);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: c)),
    );
  }

  Widget _salaryTag(int salary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Text(
        '${_formatSalary(salary)} ₸/мес',
        style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF15803D)),
      ),
    );
  }
}

String _formatSalary(int salary) {
  if (salary >= 1000) {
    return '${(salary / 1000).toStringAsFixed(salary % 1000 == 0 ? 0 : 1)}K';
  }
  return salary.toString();
}

// ── Match badge ───────────────────────────────────────────────────────────────

class _MatchBadge extends StatelessWidget {
  final int score;
  const _MatchBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score >= 85
        ? const Color(0xFF16A34A)
        : score >= 70
            ? const Color(0xFFD97706)
            : const Color(0xFF9CA3AF);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text('$score%',
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

// ── Quick AI row ──────────────────────────────────────────────────────────────

class _QuickAiRow extends StatelessWidget {
  final Internship internship;
  const _QuickAiRow({required this.internship});

  void _openAi(BuildContext context, AiChatMode mode) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AiChatScreen(
        mode: mode,
        internshipId: internship.id,
        internshipTitle: internship.title,
        companyName: internship.company,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.auto_awesome_rounded, size: 12, color: Color(0xFF9CA3AF)),
        const SizedBox(width: 6),
        _AiChip(
          label: 'Cover letter',
          onTap: () => _openAi(context, AiChatMode.coverLetter),
        ),
        const SizedBox(width: 6),
        _AiChip(
          label: 'Собеседование',
          onTap: () => _openAi(context, AiChatMode.interviewPrep),
        ),
        const SizedBox(width: 6),
        _AiChip(
          label: 'Навыки',
          onTap: () => _openAi(context, AiChatMode.skillGap),
        ),
      ],
    );
  }
}

class _AiChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _AiChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2557A7),
            decoration: TextDecoration.underline,
            decorationColor: Color(0xFFBFDBFE),
          ),
        ),
      ),
    );
  }
}
