import 'package:flutter/material.dart';
import 'package:internship_app2/l10n/strings.dart';

enum SortOption { defaultSort, salaryDesc, salaryAsc }

String sortLabel(SortOption opt) {
  switch (opt) {
    case SortOption.defaultSort:
      return tr('sort_default');
    case SortOption.salaryDesc:
      return tr('sort_salary_desc');
    case SortOption.salaryAsc:
      return tr('sort_salary_asc');
  }
}

class FilterOptions {
  final Set<String> cities;
  final Set<String> formats;
  final bool paidOnly;
  final SortOption sort;

  const FilterOptions({
    this.cities = const {},
    this.formats = const {},
    this.paidOnly = false,
    this.sort = SortOption.defaultSort,
  });

  bool get isEmpty =>
      cities.isEmpty && formats.isEmpty && !paidOnly && sort == SortOption.defaultSort;

  int get activeCount =>
      (cities.isNotEmpty ? 1 : 0) +
      (formats.isNotEmpty ? 1 : 0) +
      (paidOnly ? 1 : 0) +
      (sort != SortOption.defaultSort ? 1 : 0);

  FilterOptions copyWith({
    Set<String>? cities,
    Set<String>? formats,
    bool? paidOnly,
    SortOption? sort,
  }) {
    return FilterOptions(
      cities: cities ?? this.cities,
      formats: formats ?? this.formats,
      paidOnly: paidOnly ?? this.paidOnly,
      sort: sort ?? this.sort,
    );
  }
}

class FilterSheet extends StatefulWidget {
  final FilterOptions current;
  final List<String> availableCities;
  final List<String> availableFormats;
  final void Function(FilterOptions) onApply;

  const FilterSheet({
    super.key,
    required this.current,
    required this.availableCities,
    required this.availableFormats,
    required this.onApply,
  });

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late Set<String> _cities;
  late Set<String> _formats;
  late bool _paidOnly;
  late SortOption _sort;

  @override
  void initState() {
    super.initState();
    _cities = Set.of(widget.current.cities);
    _formats = Set.of(widget.current.formats);
    _paidOnly = widget.current.paidOnly;
    _sort = widget.current.sort;
  }

  void _reset() => setState(() {
        _cities.clear();
        _formats.clear();
        _paidOnly = false;
        _sort = SortOption.defaultSort;
      });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
            child: Row(
              children: [
                Text(
                  tr('filters_title'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _reset,
                  child: Text(
                    tr('reset'),
                    style: TextStyle(color: cs.error, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // Sort
                  _sectionLabel(tr('filter_sort')),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: SortOption.values.map((opt) {
                      final selected = _sort == opt;
                      return _filterChip(
                        label: sortLabel(opt),
                        selected: selected,
                        onTap: () => setState(() => _sort = opt),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // Paid only
                  _sectionLabel(tr('filter_pay')),
                  const SizedBox(height: 8),
                  _toggleChip(
                    label: tr('paid_only'),
                    icon: Icons.attach_money_rounded,
                    selected: _paidOnly,
                    color: const Color(0xFF22C55E),
                    onTap: () => setState(() => _paidOnly = !_paidOnly),
                  ),

                  const SizedBox(height: 20),

                  // Format
                  _sectionLabel(tr('filter_format')),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.availableFormats.map((f) {
                      final selected = _formats.contains(f);
                      return _filterChip(
                        label: f,
                        selected: selected,
                        onTap: () => setState(() {
                          selected ? _formats.remove(f) : _formats.add(f);
                        }),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // Cities
                  _sectionLabel(tr('filter_city')),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.availableCities.map((c) {
                      final selected = _cities.contains(c);
                      return _filterChip(
                        label: c,
                        selected: selected,
                        onTap: () => setState(() {
                          selected ? _cities.remove(c) : _cities.add(c);
                        }),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Apply button
          Padding(
            padding: EdgeInsets.fromLTRB(
                20, 8, 20, MediaQuery.paddingOf(context).bottom + 16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () {
                  widget.onApply(FilterOptions(
                    cities: _cities,
                    formats: _formats,
                    paidOnly: _paidOnly,
                    sort: _sort,
                  ));
                  Navigator.pop(context);
                },
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  tr('apply_filter'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _toggleChip({
    required String label,
    required IconData icon,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? color : const Color(0xFF6B7280)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? color : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
