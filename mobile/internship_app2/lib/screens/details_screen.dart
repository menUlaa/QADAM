import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:internship_app2/l10n/strings.dart';
import 'package:internship_app2/models/internship.dart';
import 'package:internship_app2/screens/ai_chat_screen.dart';
import 'package:internship_app2/services/api_service.dart';

const _categoryColors = {
  'IT': Color(0xFF2164F3),
  'Финансы': Color(0xFF047857),
  'Дизайн': Color(0xFFB45309),
  'Маркетинг': Color(0xFFDC2626),
  'HR': Color(0xFF7C3AED),
};

Color _accentFor(String cat) =>
    _categoryColors[cat] ?? const Color(0xFF2164F3);

class DetailsScreen extends StatefulWidget {
  final Internship internship;
  const DetailsScreen({super.key, required this.internship});

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  final _apiService = ApiService();
  bool _applying = false;
  bool _applied = false;

  Future<void> _share() async {
    final text =
        '${widget.internship.title} — ${widget.internship.company}\n${tr('contact')}: ${widget.internship.contactEmail}';
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('copied')),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _showApplyDialog() async {
    final messageController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(tr('apply_dialog_title'),
            style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.internship.title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15)),
            Text(widget.internship.company,
                style: const TextStyle(
                    color: Color(0xFF6B7280), fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: tr('apply_message_hint'),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel'),
                style:
                    const TextStyle(color: Color(0xFF6B7280))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2164F3),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('apply_send')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _applying = true);
    try {
      await _apiService.apply(widget.internship.id,
          message: messageController.text);
      setState(() => _applied = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('apply_success')),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.internship;
    final accent = _accentFor(it.category);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          color: Color(0xFF111827),
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        title: Text(it.company),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, size: 20),
            tooltip: tr('share'),
            onPressed: _share,
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE5E7EB)),
        ),
      ),

      // ── Sticky apply button ──────────────────────────────────────────────
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, MediaQuery.paddingOf(context).bottom + 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        ),
        child: SizedBox(
          height: 50,
          child: FilledButton(
            onPressed: _applied || _applying ? null : _showApplyDialog,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2164F3),
              disabledBackgroundColor: const Color(0xFFD1D5DB),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: _applying
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _applied ? Icons.check_circle : Icons.send_rounded,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _applied
                            ? tr('applied_btn')
                            : tr('apply_btn'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),

      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        children: [
          // ── Hero card ────────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 16,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Gradient accent stripe
                  Container(
                    height: 5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accent, accent.withValues(alpha: 0.45)],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Company avatar
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: accent.withValues(alpha: 0.2)),
                      ),
                      child: Center(
                        child: Text(
                          it.company
                              .trim()
                              .split(' ')
                              .map((w) => w.isNotEmpty ? w[0] : '')
                              .take(2)
                              .join()
                              .toUpperCase(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: accent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            it.title,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            it.company,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _pillChip(Icons.location_on_outlined, it.city,
                        const Color(0xFF6B7280)),
                    _pillChip(Icons.work_outline_rounded, it.format,
                        const Color(0xFF6B7280)),
                    if (it.salaryKzt != null)
                      _pillChip(
                        Icons.payments_outlined,
                        '${it.salaryKzt} ₸',
                        const Color(0xFF15803D),
                        bg: const Color(0xFFF0FDF4),
                        border: const Color(0xFFBBF7D0),
                      ),
                    if (it.duration.isNotEmpty)
                      _pillChip(Icons.schedule_rounded, it.duration,
                          const Color(0xFF6B7280)),
                    _pillChip(
                      it.paid
                          ? Icons.attach_money
                          : Icons.money_off_outlined,
                      it.paid ? tr('paid') : tr('unpaid'),
                      it.paid
                          ? const Color(0xFF15803D)
                          : const Color(0xFF9CA3AF),
                      bg: it.paid
                          ? const Color(0xFFF0FDF4)
                          : const Color(0xFFF9FAFB),
                      border: it.paid
                          ? const Color(0xFFBBF7D0)
                          : const Color(0xFFE5E7EB),
                    ),
                  ],
                ),
              ],
            ),           // inner Column
          ),             // Padding
                ],       // outer Column children
              ),         // outer Column
            ),           // ClipRRect
          ),             // hero Container

          const SizedBox(height: 16),

          // ── Description ──────────────────────────────────────────────────
          _section(
            tr('description'),
            child: Text(
              it.description,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF374151),
                height: 1.6,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Responsibilities ─────────────────────────────────────────────
          if (it.responsibilities.isNotEmpty)
            _section(
              tr('responsibilities'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children:
                    it.responsibilities.map(_bullet).toList(),
              ),
            ),

          const SizedBox(height: 12),

          // ── Requirements ─────────────────────────────────────────────────
          if (it.requirements.isNotEmpty)
            _section(
              tr('requirements'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: it.requirements.map(_bullet).toList(),
              ),
            ),

          const SizedBox(height: 12),

          // ── Skills ───────────────────────────────────────────────────────
          if (it.skills.isNotEmpty)
            _section(
              tr('skills'),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: it.skills
                    .map((s) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEBF0FA),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            s,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2164F3),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),

          const SizedBox(height: 12),

          // ── AI Preparation ───────────────────────────────────────────────
          _AiPreparationSection(internship: it),

          const SizedBox(height: 12),

          // ── Contact ──────────────────────────────────────────────────────
          _section(
            tr('contact'),
            child: Row(
              children: [
                const Icon(Icons.email_outlined,
                    size: 18, color: Color(0xFF2164F3)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    it.contactEmail,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF2164F3),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _pillChip(
    IconData icon,
    String label,
    Color color, {
    Color bg = const Color(0xFFF9FAFB),
    Color border = const Color(0xFFE5E7EB),
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── AI Preparation Section ─────────────────────────────────────────────────────

class _AiPreparationSection extends StatelessWidget {
  final Internship internship;
  const _AiPreparationSection({required this.internship});

  void _open(BuildContext context, AiChatMode mode) {
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
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF2164F3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2164F3).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AI Подготовка',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800)),
                    Text('Готов к этой стажировке?',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12)),
                  ],
                ),
              ),
              if (internship.matchScore != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${internship.matchScore}% match',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _AiActionButton(
            icon: Icons.description_outlined,
            title: 'Сопроводительное письмо',
            subtitle: 'AI напишет письмо под эту вакансию',
            onTap: () => _open(context, AiChatMode.coverLetter),
          ),
          const SizedBox(height: 8),
          _AiActionButton(
            icon: Icons.record_voice_over_outlined,
            title: 'Подготовка к собеседованию',
            subtitle: 'Топ вопросов + советы для этой компании',
            onTap: () => _open(context, AiChatMode.interviewPrep),
          ),
          const SizedBox(height: 8),
          _AiActionButton(
            icon: Icons.analytics_outlined,
            title: 'Анализ навыков',
            subtitle: 'Что прокачать перед откликом',
            onTap: () => _open(context, AiChatMode.skillGap),
          ),
        ],
      ),
    );
  }
}

class _AiActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AiActionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white54, size: 14),
          ],
        ),
      ),
    );
  }
}

Widget _section(String title, {required Widget child}) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [
        BoxShadow(
          color: Color(0x08000000),
          blurRadius: 12,
          offset: Offset(0, 2),
        ),
      ],
    ),
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title with left accent bar
        Row(
          children: [
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xFF2164F3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

Widget _bullet(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 5),
          child: CircleAvatar(
            radius: 3,
            backgroundColor: Color(0xFF2164F3),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF374151),
              height: 1.5,
            ),
          ),
        ),
      ],
    ),
  );
}
