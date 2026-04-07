import 'package:flutter/material.dart';

class SkeletonCard extends StatefulWidget {
  const SkeletonCard({super.key});

  @override
  State<SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) {
        final opacity = 0.06 + _anim.value * 0.08;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            elevation: 1.2,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _box(40, 40, radius: 12, opacity: opacity),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _box(16, double.infinity, opacity: opacity),
                            const SizedBox(height: 6),
                            _box(12, 120, opacity: opacity),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _box(24, 60, radius: 12, opacity: opacity),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _box(12, 80, radius: 20, opacity: opacity),
                      const SizedBox(width: 8),
                      _box(12, 70, radius: 20, opacity: opacity),
                      const SizedBox(width: 8),
                      _box(12, 90, radius: 20, opacity: opacity),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _box(12, double.infinity, opacity: opacity),
                  const SizedBox(height: 6),
                  _box(12, 200, opacity: opacity),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _box(double height, double width,
      {double radius = 8, required double opacity}) {
    return Container(
      height: height,
      width: width == double.infinity ? null : width,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
