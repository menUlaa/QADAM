import 'package:flutter/material.dart';
import 'package:internship_app2/services/api_service.dart';

class CompanyDashboardScreen extends StatefulWidget {
  final String token;
  final String companyName;
  const CompanyDashboardScreen({
    super.key,
    required this.token,
    required this.companyName,
  });

  @override
  State<CompanyDashboardScreen> createState() => _CompanyDashboardScreenState();
}

class _CompanyDashboardScreenState extends State<CompanyDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late final TabController _tabs;

  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _internships = [];
  List<Map<String, dynamic>> _applications = [];
  bool _loadingStats = true;
  bool _loadingInternships = true;
  bool _loadingApps = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    _loadStats();
    _loadInternships();
    _loadApplications();
  }

  Future<void> _loadStats() async {
    try {
      final data = await _api.getCompanyStats(widget.token);
      if (mounted) setState(() { _stats = data; _loadingStats = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  Future<void> _loadInternships() async {
    try {
      final data = await _api.getCompanyInternshipsList(widget.token);
      if (mounted) setState(() { _internships = data; _loadingInternships = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingInternships = false);
    }
  }

  Future<void> _loadApplications() async {
    try {
      final data = await _api.getCompanyApplications(widget.token);
      if (mounted) setState(() { _applications = data; _loadingApps = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingApps = false);
    }
  }

  Future<void> _updateStatus(int appId, String status) async {
    try {
      await _api.updateApplicationStatus(widget.token, appId, status);
      _loadApplications();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  void _openAddInternship() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddInternshipSheet(
        token: widget.token,
        api: _api,
        onCreated: _loadInternships,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.companyName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const Text('Кабинет компании',
                style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: const Color(0xFF2164F3),
          labelColor: const Color(0xFF2164F3),
          unselectedLabelColor: const Color(0xFF6B7280),
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'Статистика'),
            Tab(text: 'Вакансии'),
            Tab(text: 'Заявки'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildStats(),
          _buildInternships(),
          _buildApplications(),
        ],
      ),
      floatingActionButton: ListenableBuilder(
        listenable: _tabs,
        builder: (_, w) => _tabs.index == 1
            ? FloatingActionButton.extended(
                onPressed: _openAddInternship,
                backgroundColor: const Color(0xFF2164F3),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Добавить', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  // ── Stats tab ────────────────────────────────────────────────────────────────

  Widget _buildStats() {
    if (_loadingStats) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF2164F3)));
    }
    final cards = [
      ('Вакансии', '${_stats['total_internships'] ?? 0}', Icons.work_outline, const Color(0xFF2164F3)),
      ('Заявки', '${_stats['total_applications'] ?? 0}', Icons.inbox_outlined, const Color(0xFF8B5CF6)),
      ('Принято', '${_stats['accepted'] ?? 0}', Icons.check_circle_outline, const Color(0xFF10B981)),
      ('Отклонено', '${_stats['rejected'] ?? 0}', Icons.cancel_outlined, const Color(0xFFDC2626)),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: cards.map((c) => _StatCard(label: c.$1, value: c.$2, icon: c.$3, color: c.$4)).toList(),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ожидают рассмотрения', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
              const SizedBox(height: 4),
              Text(
                '${_stats['pending'] ?? 0} заявок',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFFF59E0B)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Internships tab ──────────────────────────────────────────────────────────

  Widget _buildInternships() {
    if (_loadingInternships) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF2164F3)));
    }
    if (_internships.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.work_off_outlined, size: 56, color: Color(0xFFD1D5DB)),
            SizedBox(height: 12),
            Text('Нет вакансий', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
            Text('Нажмите + чтобы добавить', style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _internships.length,
      separatorBuilder: (_, w) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _InternshipTile(data: _internships[i]),
    );
  }

  // ── Applications tab ─────────────────────────────────────────────────────────

  Widget _buildApplications() {
    if (_loadingApps) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF2164F3)));
    }
    if (_applications.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 56, color: Color(0xFFD1D5DB)),
            SizedBox(height: 12),
            Text('Нет заявок', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _applications.length,
      separatorBuilder: (_, w) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final app = _applications[i];
        final status = app['status'] as String? ?? 'pending';
        return _ApplicationTile(
          data: app,
          onAccept: status == 'pending' ? () => _updateStatus(app['id'], 'accepted') : null,
          onReject: status == 'pending' ? () => _updateStatus(app['id'], 'rejected') : null,
        );
      },
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
              Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Internship tile ───────────────────────────────────────────────────────────

class _InternshipTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _InternshipTile({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEBF0FA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.work_outline, color: Color(0xFF2164F3), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['title'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                Text(data['category'] ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                data['is_paid'] == true ? 'Оплачиваемая' : 'Волонтёрская',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: data['is_paid'] == true ? const Color(0xFF10B981) : const Color(0xFF6B7280),
                ),
              ),
              Text(
                data['format'] ?? '',
                style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Application tile ──────────────────────────────────────────────────────────

class _ApplicationTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  const _ApplicationTile({required this.data, this.onAccept, this.onReject});

  @override
  Widget build(BuildContext context) {
    final status = data['status'] as String? ?? 'pending';
    final statusColor = switch (status) {
      'accepted' => const Color(0xFF10B981),
      'rejected' => const Color(0xFFDC2626),
      _ => const Color(0xFFF59E0B),
    };
    final statusLabel = switch (status) {
      'accepted' => 'Принято',
      'rejected' => 'Отклонено',
      _ => 'На рассмотрении',
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFEBF0FA),
                child: Text(
                  (data['user_name'] as String? ?? '?').isNotEmpty
                      ? (data['user_name'] as String)[0].toUpperCase()
                      : '?',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF2164F3)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['user_name'] ?? 'Студент', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    Text(data['internship_title'] ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
              ),
            ],
          ),
          if (data['message'] != null && (data['message'] as String).isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              data['message'] as String,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (status == 'pending') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFECACA)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Отклонить', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: onAccept,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Принять', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Add internship bottom sheet ───────────────────────────────────────────────

class _AddInternshipSheet extends StatefulWidget {
  final String token;
  final ApiService api;
  final VoidCallback onCreated;
  const _AddInternshipSheet({required this.token, required this.api, required this.onCreated});

  @override
  State<_AddInternshipSheet> createState() => _AddInternshipSheetState();
}

class _AddInternshipSheetState extends State<_AddInternshipSheet> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _city = TextEditingController();
  String _category = 'IT';
  String _format = 'Офис';
  bool _isPaid = false;
  bool _saving = false;
  String? _error;

  static const _categories = ['IT', 'Финансы', 'Дизайн', 'Маркетинг', 'HR', 'Другое'];
  static const _formats = ['Офис', 'Удалённо', 'Гибрид'];

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Введите название вакансии');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await widget.api.createCompanyInternship(widget.token, {
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'city': _city.text.trim(),
        'category': _category,
        'format': _format,
        'is_paid': _isPaid,
      });
      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); _saving = false; });
    }
  }

  @override
  void dispose() { _title.dispose(); _description.dispose(); _city.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            const Text('Новая вакансия', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            _field(_title, 'Название', Icons.work_outline),
            const SizedBox(height: 10),
            _field(_description, 'Описание', Icons.description_outlined, maxLines: 3),
            const SizedBox(height: 10),
            _field(_city, 'Город', Icons.location_on_outlined),
            const SizedBox(height: 12),
            // Category chips
            const Text('Категория', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: _categories.map((c) => ChoiceChip(
                label: Text(c),
                selected: _category == c,
                onSelected: (_) => setState(() => _category = c),
                selectedColor: const Color(0xFFEBF0FA),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _category == c ? const Color(0xFF2164F3) : const Color(0xFF374151),
                ),
              )).toList(),
            ),
            const SizedBox(height: 12),
            // Format chips
            const Text('Формат', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: _formats.map((f) => ChoiceChip(
                label: Text(f),
                selected: _format == f,
                onSelected: (_) => setState(() => _format = f),
                selectedColor: const Color(0xFFEBF0FA),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _format == f ? const Color(0xFF2164F3) : const Color(0xFF374151),
                ),
              )).toList(),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Оплачиваемая стажировка', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              value: _isPaid,
              onChanged: (v) => setState(() => _isPaid = v),
              activeThumbColor: const Color(0xFF2164F3),
              contentPadding: EdgeInsets.zero,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(fontSize: 13, color: Color(0xFFDC2626))),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2164F3),
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Создать вакансию', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2164F3), width: 1.5)),
      ),
    );
  }
}
