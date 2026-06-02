import 'package:flutter/material.dart';
import 'package:internship_app2/services/api_service.dart';

// ── Kanban pipeline stages ─────────────────────────────────────────────────────

const _stages = [
  _Stage('pending',   'Новые',       Color(0xFFF59E0B), Icons.inbox_outlined),
  _Stage('reviewed',  'Рассмотрено', Color(0xFF2164F3), Icons.visibility_outlined),
  _Stage('interview', 'Интервью',    Color(0xFF8B5CF6), Icons.videocam_outlined),
  _Stage('offer',     'Оффер',       Color(0xFF10B981), Icons.local_offer_outlined),
  _Stage('accepted',  'Принято',     Color(0xFF059669), Icons.check_circle_outline),
  _Stage('rejected',  'Отклонено',   Color(0xFFDC2626), Icons.cancel_outlined),
];

class _Stage {
  final String key;
  final String label;
  final Color color;
  final IconData icon;
  const _Stage(this.key, this.label, this.color, this.icon);
}

String? _nextStage(String current) => switch (current) {
  'pending'   => 'reviewed',
  'reviewed'  => 'interview',
  'interview' => 'offer',
  'offer'     => 'accepted',
  _           => null,
};

// ── Screen ────────────────────────────────────────────────────────────────────

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

  // Kanban filters
  int? _filterInternshipId;
  String _filterSkill = '';
  String _filterSpecialty = '';
  final Map<int, Map<String, dynamic>> _aiScores = {};
  final Map<int, bool> _scoringInProgress = {};

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
      _loadStats();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _scoreWithAi(int appId) async {
    if (_scoringInProgress[appId] == true) return;
    setState(() => _scoringInProgress[appId] = true);
    try {
      final result = await _api.scoreCandidateWithAi(widget.token, appId);
      if (mounted) setState(() { _aiScores[appId] = result; _scoringInProgress[appId] = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _scoringInProgress[appId] = false);
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

  void _openEditInternship(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditInternshipSheet(
        token: widget.token,
        api: _api,
        data: data,
        onSaved: _loadInternships,
      ),
    );
  }

  Future<void> _deleteInternship(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить вакансию?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Color(0xFFDC2626))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.deleteCompanyInternship(widget.token, id);
      _loadInternships();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
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
            Tab(text: 'Пайплайн'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildStats(),
          _buildInternships(),
          _buildKanban(),
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

  Widget _statCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            ],
          ),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Color(0xFF2164F3))),
        ],
      ),
    );
  }

  Widget _buildStats() {
    if (_loadingStats) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF2164F3)));
    }
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Статистика',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF0F1117))),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.2,
            children: [
              _statCard('Вакансии',        '${_stats['total_internships'] ?? 0}', Icons.work_outline),
              _statCard('Всего заявок',    '${_stats['total_applications'] ?? 0}', Icons.inbox_outlined),
              _statCard('На рассмотрении', '${_stats['pending'] ?? 0}',            Icons.hourglass_empty),
              _statCard('Офферы',          '${_stats['offer'] ?? 0}',              Icons.check_circle_outline),
            ],
          ),
        ],
      ),
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
      itemBuilder: (_, i) => _InternshipTile(
        data: _internships[i],
        onEdit: () => _openEditInternship(_internships[i]),
        onDelete: () => _deleteInternship(_internships[i]['id'] as int),
      ),
    );
  }

  // ── Pipeline tab ─────────────────────────────────────────────────────────────

  Widget _buildKanban() {
    if (_loadingApps) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF2164F3)));
    }

    final internshipOptions = <Map<String, dynamic>>[
      {'id': null, 'title': 'Все вакансии'},
      ..._internships,
    ];

    final apps = _filterInternshipId == null
        ? _applications
        : _applications.where((a) => a['internship_id'] == _filterInternshipId).toList();

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              const Icon(Icons.filter_list_rounded, size: 18, color: Color(0xFF6B7280)),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: _filterInternshipId,
                    isDense: true,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF111827), fontWeight: FontWeight.w600),
                    items: internshipOptions.map((opt) => DropdownMenuItem<int?>(
                      value: opt['id'] as int?,
                      child: Text(opt['title'] as String, overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (v) => setState(() => _filterInternshipId = v),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${apps.length} заявок',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2164F3))),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: apps.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_outlined, size: 56, color: Color(0xFFD1D5DB)),
                      SizedBox(height: 12),
                      Text('Нет заявок',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: apps.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _AppListCard(
                    app: apps[i],
                    onStatusChange: _updateStatus,
                    onTap: () => _showCandidateDetail(context, apps[i]),
                  ),
                ),
        ),
      ],
    );
  }

  void _showCandidateDetail(BuildContext context, Map<String, dynamic> app) {
    final aiScore = _aiScores[app['id'] as int];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CandidateDetailSheet(
        app: app,
        aiScore: aiScore,
        token: widget.token,
        api: _api,
        onStatusChange: _updateStatus,
        onScore: () => _scoreWithAi(app['id'] as int),
        isScoring: _scoringInProgress[app['id'] as int] == true,
      ),
    );
  }
}

// ── Candidate detail bottom sheet ─────────────────────────────────────────────

class _CandidateDetailSheet extends StatelessWidget {
  final Map<String, dynamic> app;
  final Map<String, dynamic>? aiScore;
  final String token;
  final ApiService api;
  final Future<void> Function(int, String) onStatusChange;
  final VoidCallback onScore;
  final bool isScoring;

  const _CandidateDetailSheet({
    required this.app,
    required this.aiScore,
    required this.token,
    required this.api,
    required this.onStatusChange,
    required this.onScore,
    required this.isScoring,
  });

  @override
  Widget build(BuildContext context) {
    final name = app['student_name'] as String? ?? 'Студент';
    final email = app['student_email'] as String? ?? '';
    final university = app['student_university'] as String? ?? '';
    final specialty = app['student_specialty'] as String? ?? '';
    final skills = (app['student_skills'] as List?)?.cast<String>() ?? [];
    final message = app['message'] as String? ?? '';
    final currentStage = _stages.firstWhere((s) => s.key == (app['status'] as String? ?? 'pending'));
    final nextStageKey = _nextStage(currentStage.key);
    final isTerminal = currentStage.key == 'accepted' || currentStage.key == 'rejected';

    final scoreVal = aiScore?['score'] as int?;
    final strengths = (aiScore?['strengths'] as List?)?.cast<String>() ?? [];
    final gaps = (aiScore?['gaps'] as List?)?.cast<String>() ?? [];
    final scoreColor = scoreVal == null
        ? const Color(0xFF9CA3AF)
        : scoreVal >= 75
            ? const Color(0xFF10B981)
            : scoreVal >= 50
                ? const Color(0xFFF59E0B)
                : const Color(0xFFDC2626);

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: currentStage.color.withValues(alpha: 0.12),
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: currentStage.color)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                      if (email.isNotEmpty)
                        Text(email, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: currentStage.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: currentStage.color.withValues(alpha: 0.3)),
                  ),
                  child: Text(currentStage.label,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: currentStage.color)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            // Education
            if (university.isNotEmpty) ...[
              _detailRow(Icons.school_outlined, 'Университет', university),
              if (specialty.isNotEmpty) _detailRow(Icons.book_outlined, 'Специальность', specialty),
              const SizedBox(height: 8),
            ],
            // Skills
            if (skills.isNotEmpty) ...[
              const Text('Навыки', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 5,
                children: skills.map((s) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Text(s, style: const TextStyle(fontSize: 12, color: Color(0xFF2164F3), fontWeight: FontWeight.w600)),
                )).toList(),
              ),
              const SizedBox(height: 12),
            ],
            // Cover letter
            if (message.isNotEmpty) ...[
              const Text('Сопроводительное письмо',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Text(message, style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.5)),
              ),
              const SizedBox(height: 12),
            ],
            // AI score section
            if (aiScore != null) ...[
              const Text('AI Оценка', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: scoreColor.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('$scoreVal%',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: scoreColor)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            aiScore!['summary'] as String? ?? '',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
                          ),
                        ),
                      ],
                    ),
                    if (strengths.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Text('Сильные стороны:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
                      ...strengths.map((s) => Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(children: [
                          const Icon(Icons.check_circle_outline, size: 13, color: Color(0xFF059669)),
                          const SizedBox(width: 6),
                          Expanded(child: Text(s, style: const TextStyle(fontSize: 12, color: Color(0xFF374151)))),
                        ]),
                      )),
                    ],
                    if (gaps.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text('Пробелы:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                      ...gaps.map((g) => Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(children: [
                          const Icon(Icons.info_outline, size: 13, color: Color(0xFFDC2626)),
                          const SizedBox(width: 6),
                          Expanded(child: Text(g, style: const TextStyle(fontSize: 12, color: Color(0xFF374151)))),
                        ]),
                      )),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ] else ...[
              FilledButton.icon(
                onPressed: isScoring ? null : onScore,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2164F3),
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: isScoring
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_awesome_outlined, size: 16),
                label: Text(isScoring ? 'Оценка...' : 'Оценить с AI',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 12),
            ],
            // Action buttons
            if (!isTerminal) ...[
              const Divider(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onStatusChange(app['id'] as int, 'rejected');
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFFECACA)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Отклонить', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  if (nextStageKey != null) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          onStatusChange(app['id'] as int, nextStageKey);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: currentStage.color,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                        label: Text(
                          _stages.firstWhere((s) => s.key == nextStageKey).label,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF9CA3AF)),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, color: Color(0xFF374151), fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Color(0xFF2164F3))),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }
}

// ── Internship tile ───────────────────────────────────────────────────────────

class _InternshipTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _InternshipTile({required this.data, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isPaid = data['is_paid'] == true || data['is_paid'] == 1;
    final salaryKzt = data['salary_kzt'] as int?;
    final salaryText = isPaid
        ? (salaryKzt != null ? '${(salaryKzt / 1000).round()}K ₸/мес' : 'Оплачиваемая')
        : 'Волонтёрская';
    final salaryColor = isPaid ? const Color(0xFF059669) : const Color(0xFF6B7280);
    final salaryBg    = isPaid ? const Color(0xFFECFDF5) : const Color(0xFFF3F4F6);
    final category    = (data['category'] as String?) ?? '';
    final format      = (data['format']   as String?) ?? '';
    final city        = (data['city']     as String?) ?? '';
    final appCount    = data['applications_count'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40, height: 40,
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
                    Text(data['title'] ?? '',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF111827))),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (category.isNotEmpty)
                          _Pill(category, const Color(0xFF2164F3), const Color(0xFFEFF4FF)),
                        if (format.isNotEmpty)
                          _Pill(format, const Color(0xFF6B7280), const Color(0xFFF3F4F6)),
                        _Pill(salaryText, salaryColor, salaryBg),
                        if (city.isNotEmpty)
                          _Pill(city, const Color(0xFF6B7280), const Color(0xFFF3F4F6)),
                      ],
                    ),
                  ],
                ),
              ),
              if (appCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF4FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$appCount заявок',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2164F3),
                      )),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 0.5, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Редактировать', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2164F3),
                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: onDelete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                  side: const BorderSide(color: Color(0xFFFECACA)),
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Icon(Icons.delete_outline, size: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Pill ──────────────────────────────────────────────────────────────────────

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  final Color bg;
  const _Pill(this.text, this.color, this.bg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ── Pipeline application card ─────────────────────────────────────────────────

class _AppListCard extends StatelessWidget {
  final Map<String, dynamic> app;
  final Future<void> Function(int, String) onStatusChange;
  final VoidCallback onTap;

  const _AppListCard({
    required this.app,
    required this.onStatusChange,
    required this.onTap,
  });

  static const _avatarColors = [
    Color(0xFF3B82F6), Color(0xFF8B5CF6), Color(0xFF10B981),
    Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFF06B6D4),
  ];

  Color _avatarColor(String name) =>
      _avatarColors[name.codeUnits.fold(0, (a, b) => a + b) % _avatarColors.length];

  String _initials(String name) {
    final words = name.trim().split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    return words.length >= 2
        ? '${words[0][0]}${words[1][0]}'.toUpperCase()
        : name[0].toUpperCase();
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      const months = ['', 'янв', 'фев', 'мар', 'апр', 'май', 'июн',
          'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
      return '${dt.day} ${months[dt.month]}';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    final name            = app['student_name']     as String? ?? 'Студент';
    final email           = app['student_email']    as String? ?? '';
    final internshipTitle = app['internship_title'] as String? ?? '';
    final status          = app['status']           as String? ?? 'pending';
    final createdAt       = app['created_at']       as String?;
    final appId           = app['id']               as int;

    final stage      = _stages.firstWhere((s) => s.key == status, orElse: () => _stages.first);
    final isTerminal = status == 'accepted' || status == 'rejected';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: avatar + name/email + status badge
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: _avatarColor(name),
                  child: Text(_initials(name),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                      if (email.isNotEmpty)
                        Text(email,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                            overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: stage.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(stage.label,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: stage.color)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Vacancy + date
            Row(
              children: [
                const Icon(Icons.work_outline_rounded, size: 13, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(internshipTitle,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
                      overflow: TextOverflow.ellipsis),
                ),
                if (createdAt != null && createdAt.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(_fmtDate(createdAt),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                ],
              ],
            ),
            const SizedBox(height: 12),
            // Status action buttons
            if (!isTerminal)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _StatusBtn(label: 'Рассмотрено', color: const Color(0xFF2164F3),
                      bg: const Color(0xFFEFF4FF), active: status == 'reviewed',
                      onTap: () => onStatusChange(appId, 'reviewed')),
                  _StatusBtn(label: 'Интервью', color: const Color(0xFF8B5CF6),
                      bg: const Color(0xFFF3F0FF), active: status == 'interview',
                      onTap: () => onStatusChange(appId, 'interview')),
                  _StatusBtn(label: 'Оффер', color: const Color(0xFF10B981),
                      bg: const Color(0xFFECFDF5), active: status == 'offer',
                      onTap: () => onStatusChange(appId, 'offer')),
                  _StatusBtn(label: 'Принять', color: const Color(0xFF059669),
                      bg: const Color(0xFFD1FAE5), active: status == 'accepted',
                      onTap: () => onStatusChange(appId, 'accepted')),
                  _StatusBtn(label: 'Отклонить', color: const Color(0xFFDC2626),
                      bg: const Color(0xFFFEE2E2), active: status == 'rejected',
                      onTap: () => onStatusChange(appId, 'rejected')),
                ],
              ),
            if (isTerminal)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: stage.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status == 'accepted' ? 'Заявка принята' : 'Заявка отклонена',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: stage.color),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Status button ─────────────────────────────────────────────────────────────

class _StatusBtn extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  final bool active;
  final VoidCallback onTap;
  const _StatusBtn({
    required this.label,
    required this.color,
    required this.bg,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? color : bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: active ? 1.0 : 0.3)),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : color,
            )),
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
              child: Container(width: 40, height: 4, decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),
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

// ── Edit internship bottom sheet ──────────────────────────────────────────────

class _EditInternshipSheet extends StatefulWidget {
  final String token;
  final ApiService api;
  final Map<String, dynamic> data;
  final VoidCallback onSaved;
  const _EditInternshipSheet({required this.token, required this.api, required this.data, required this.onSaved});

  @override
  State<_EditInternshipSheet> createState() => _EditInternshipSheetState();
}

class _EditInternshipSheetState extends State<_EditInternshipSheet> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _city;
  late String _category;
  late String _format;
  late bool _isPaid;
  bool _saving = false;
  String? _error;

  static const _categories = ['IT', 'Финансы', 'Дизайн', 'Маркетинг', 'HR', 'Другое'];
  static const _formats = ['Офис', 'Удалённо', 'Гибрид'];

  @override
  void initState() {
    super.initState();
    _title       = TextEditingController(text: widget.data['title'] as String? ?? '');
    _description = TextEditingController(text: widget.data['description'] as String? ?? '');
    _city        = TextEditingController(text: widget.data['city'] as String? ?? '');
    _category    = widget.data['category'] as String? ?? 'IT';
    _format      = widget.data['format'] as String? ?? 'Офис';
    _isPaid      = widget.data['is_paid'] as bool? ?? false;
    if (!_categories.contains(_category)) _category = 'IT';
    if (!_formats.contains(_format)) _format = 'Офис';
  }

  @override
  void dispose() { _title.dispose(); _description.dispose(); _city.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Введите название вакансии');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await widget.api.updateCompanyInternship(widget.token, widget.data['id'] as int, {
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'city': _city.text.trim(),
        'category': _category,
        'format': _format,
        'paid': _isPaid,
      });
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); _saving = false; });
    }
  }

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
              child: Container(width: 40, height: 4, decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            const Text('Редактировать вакансию', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            _field(_title, 'Название', Icons.work_outline),
            const SizedBox(height: 10),
            _field(_description, 'Описание', Icons.description_outlined, maxLines: 3),
            const SizedBox(height: 10),
            _field(_city, 'Город', Icons.location_on_outlined),
            const SizedBox(height: 12),
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
                  : const Text('Сохранить', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
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
