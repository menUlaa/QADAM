import 'package:flutter/material.dart';
import 'package:internship_app2/l10n/strings.dart';
import 'package:internship_app2/models/internship.dart';

const _categoryColors = {
  'IT': Color(0xFF2164F3),
  'Финансы': Color(0xFF047857),
  'Дизайн': Color(0xFFB45309),
  'Маркетинг': Color(0xFFDC2626),
  'HR': Color(0xFF7C3AED),
};

Color _colorFor(String category) =>
    _categoryColors[category] ?? const Color(0xFF2164F3);

String _timeAgo(DateTime? dt) {
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  final lang = localeNotifier.value;
  if (diff.inDays == 0) {
    return lang == 'en' ? 'Today' : lang == 'kz' ? 'Бүгін' : 'Сегодня';
  }
  if (diff.inDays < 7) {
    final d = diff.inDays;
    return lang == 'en'
        ? '${d}d ago'
        : lang == 'kz'
            ? '$d күн бұрын'
            : '$d дн. назад';
  }
  if (diff.inDays < 30) {
    final w = (diff.inDays / 7).floor();
    return lang == 'en'
        ? '${w}w ago'
        : lang == 'kz'
            ? '$w апта бұрын'
            : '$w нед. назад';
  }
  final m = (diff.inDays / 30).floor();
  return lang == 'en'
      ? '${m}mo ago'
      : lang == 'kz'
          ? '$m ай бұрын'
          : '$m мес. назад';
}

bool _isNew(DateTime? dt) =>
    dt != null && DateTime.now().difference(dt).inDays < 3;

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
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          hoverColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x09000000),
                  blurRadius: 12,
                  offset: Offset(0, 2),
                ),
                BoxShadow(
                  color: Color(0x05000000),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  // Colored left stripe
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 4, color: accent),
                  ),
                  // Card content
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                // ── Header: avatar + company + bookmark ─────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Company logo avatar
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: accent.withValues(alpha: 0.18)),
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            internship.company,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  internship.category,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: accent,
                                  ),
                                ),
                              ),
                              if (isNewPost) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD1FAE5),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    tr('new_badge'),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF065F46),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Bookmark
                    if (onFavoriteToggle != null)
                      GestureDetector(
                        onTap: onFavoriteToggle,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4),
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
                                  : const Color(0xFF9CA3AF),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 11),

                // ── Job title ────────────────────────────────────────────
                Text(
                  internship.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 8),

                // ── Meta chips ───────────────────────────────────────────
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (internship.city.isNotEmpty)
                      _metaChip(Icons.location_on_outlined,
                          internship.city),
                    _metaChip(Icons.work_outline_rounded, internship.format),
                    if (internship.salaryKzt != null)
                      _salaryChip(internship.salaryKzt!),
                    if (internship.duration.isNotEmpty)
                      _metaChip(Icons.schedule_rounded, internship.duration),
                  ],
                ),

                // ── Tags + date ──────────────────────────────────────────
                if (tags.isNotEmpty || dateStr.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 5,
                          runSpacing: 4,
                          children: tags
                              .map((tag) => GestureDetector(
                                    onTap: onTagTap != null
                                        ? () => onTagTap!(tag)
                                        : null,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF3F4F6),
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '#$tag',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: onTagTap != null
                                              ? const Color(0xFF2164F3)
                                              : const Color(0xFF6B7280),
                                        ),
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                      if (dateStr.isNotEmpty)
                        Text(
                          dateStr,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                    ],
                  ),
                ],
              ],         // Column.children
            ),           // Column
          ),             // content Padding
        ],               // Stack.children
      ),                 // Stack
    ),                   // ClipRRect
  ),                     // Container
),                       // InkWell
  ),                     // Material
);                       // outer Padding
  }

  Widget _metaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF6B7280)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF374151),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _salaryChip(int salary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.payments_outlined,
              size: 12, color: Color(0xFF15803D)),
          const SizedBox(width: 4),
          Text(
            '${_formatSalary(salary)} ₸',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF15803D),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
