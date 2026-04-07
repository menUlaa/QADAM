import 'package:flutter/material.dart';

/// Search bar with optional trailing widget (e.g., filter button)
class CustomSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final Widget? trailing;

  const CustomSearchBar({
    super.key,
    required this.controller,
    required this.hint,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            Icon(Icons.search, color: Colors.black.withValues(alpha: 0.55)),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: hint,
                  border: InputBorder.none,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
