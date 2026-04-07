import 'package:flutter/material.dart';

/// Pill-shaped info badge (used for tags, location, format, etc.)
Widget buildPill({
  required IconData icon,
  required String text,
  bool soft = false,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: soft ? const Color(0xFFEFF1FF) : const Color(0xFFF1F3F6),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}
