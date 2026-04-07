import 'package:flutter/material.dart';
import 'package:internship_app2/l10n/strings.dart';

/// Animated desktop footer — fades + slides in when it enters the viewport.
/// Because it lives inside a CustomScrollView sliver, it only builds when
/// the user scrolls close to it, so the animation plays at exactly the right moment.
class DesktopFooter extends StatefulWidget {
  const DesktopFooter({super.key});

  @override
  State<DesktopFooter> createState() => _DesktopFooterState();
}

class _DesktopFooterState extends State<DesktopFooter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    // Small delay so the user sees the footer arriving
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: _FooterContent(),
      ),
    );
  }
}

class _FooterContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Brand column
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Qadam',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr('footer_desc'),
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 60),

              Expanded(
                child: _FooterColumn(
                  title: tr('footer_for_students'),
                  links: [tr('nav_feed'), tr('nav_favorites'), tr('nav_profile')],
                ),
              ),
              Expanded(
                child: _FooterColumn(
                  title: tr('footer_for_universities'),
                  links: [
                    tr('footer_portal'),
                    tr('footer_analytics'),
                    tr('footer_monitoring'),
                  ],
                ),
              ),
              Expanded(
                child: _FooterColumn(
                  title: tr('footer_company'),
                  links: [
                    tr('footer_about'),
                    tr('footer_contact'),
                    tr('footer_privacy'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Divider(color: Color(0xFF374151), height: 1),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '© ${DateTime.now().year} Qadam. ${tr('footer_rights')}',
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
              ),
              Text(
                tr('footer_made_in'),
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FooterColumn extends StatelessWidget {
  final String title;
  final List<String> links;

  const _FooterColumn({required this.title, required this.links});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        ...links.map(
          (l) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l,
              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}
